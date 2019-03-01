# ceph 常用命令
## osd 替换
osd 机器上执行：
```sh
systemctl stop ceph-osd\*.service ceph-osd.target
for ((i=1; i<=15; i++)); do
  ceph osd out osd.$i
  ceph osd crush remove osd.$i
  ceph osd rm osd.$i
  ceph auth del osd.$i
done
```

admin 机器上执行：
```sh
# 手工删除 /data /data1 /data2 /data3 里的数据

sudo ceph-deploy --overwrite-conf osd prepare \
  bjtc_58_50:/data bjtc_58_50:/data1 bjtc_58_50:/data2 bjtc_58_50:/data3

sudo ceph-deploy osd activate \
  bjtc_58_50:/data bjtc_58_50:/data1 bjtc_58_50:/data2 bjtc_58_50:/data3
```

重启 rsd
```sh
systemctl restart ceph-osd@1
```

## incomplete 修复
```sh
# 查看 pg 的osd 分布
ceph pg map 5.24

ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-11/ \
  --pgid 5.24 --op mark-complete
```

## 创建用户与授权
```sh
set -euo pipefail

if [ $# != 2 ]; then
  echo "Usage: $0 user pool $#"
  exit 1
fi

user=${1}
pool=${2}

# 1. 创建用户与授权
radosgw-admin user create --uid=${user} --display-name=${user}
radosgw-admin caps add --uid=${user} --caps="users=read,write"
radosgw-admin caps add --uid=${user} --caps="usage=read,write"

# 2. 设置 placement
radosgw-admin metadata get user:${user} > ${user}.md.json
sed -i "s/\"default_placement\".*/\"default_placement\": \"${user}-placement\",/" \
  ${user}.md.json
radosgw-admin metadata put user:${user} < ${user}.md.json

# 3. 更新 zone
pool_template=$(cat <<EOF
        {
            "key": "${user}-placement",
            "val": {
                "index_pool": "default.rgw.buckets.index",
                "data_pool": "${pool}",
                "data_extra_pool": "default.rgw.buckets.non-ec",
                "index_type": 0,
                "compression": ""
            }
        },
EOF
)
echo "$pool_template" > pool_template.txt

radosgw-admin zone get --rgw-zone=default > ${user}.zone.json
sed -i '/placement_pools/r pool_template.txt' ${user}.zone.json
radosgw-admin zone set --rgw-zone=default --infile ${user}.zone.json

# 4. 更新 zone
radosgw-admin zonegroup add --rgw-zonegroup=default --rgw-zone=default
线上环境op已创建fe.ceph用户及授权（使用的默认default）
```
