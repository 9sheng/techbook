# ceph 常用命令

## pool
### 查看 pool
```sh
ceph osd lspools # pool 列表
rados df         # pool 状态
```

### 创建 pool
```sh
# 创建一个test-pool，pg_num为128
ceph osd pool create test-pool 128
# 设置允许最大object数量为100
ceph osd pool set-quota test-pool max_objects 100
# 设置允许容量限制为10GB，取消配额限制只需要把对应值设为0即可
ceph osd pool set-quota test-pool max_bytes $((10 * 1024 * 1024 * 1024))
# 重命名 pool
ceph osd pool rename test-pool test-pool-new
# 删除 pool
ceph osd pool delete test-pool test-pool --yes-i-really-really-mean-it
```

### 设置参数
```sh
# 设置pool的冗余副本数量为3
ceph osd pool set {pool_name} size 3
# 获取当前pg_num：
ceph osd pool get {pool_name} pg_num
# 获取当前副本数
ceph osd pool get {pool_name} size
```

## pg
### 查看 pg
```sh
# 查看pg信息，包括状态，对应的osd
ceph pg dump
# pg映射OSD位置，【8,5】指osd.8和osd.5 2副本，osd.8为主副本
osdmap e99 pg 1.1ff (1.1ff) -> up [8,5] acting [8,5]
```

```sh
ceph pg ls-by-primary <osd.id>
# 查看某个osd上所有pg状态
ceph pg ls-by-osd <osd.id>
```

## 修复 incomplete pg
```sh
ceph pg map 5.24  # 查看 pg 的 osd 分布

ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-11/ \
  --pgid 5.24 --op mark-complete
```

## osd
### osd 替换
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
chown -R ceph:ceph /data /data1 /data2 /data3
rm -rf /data/* /data1/* /data2/* /data3/*

sudo ceph-deploy --overwrite-conf osd prepare \
  hostname:/data hostname:/data1 hostname:/data2 hostname:/data3

sudo ceph-deploy osd activate \
  hostname:/data hostname:/data1 hostname:/data2 hostname:/data3
```

### 重启 osd
```sh
systemctl restart ceph-osd@1
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
```
