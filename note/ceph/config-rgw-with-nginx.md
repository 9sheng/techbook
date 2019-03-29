# 通过 nginx 访问 ceph.radosgw

## 增加配置
找2台机器（配置了 admin key 使之可访问 ceph 集群的），如 ttt_40_111、bjzw_98_111，将 ceph.conf 增加下列配置：
```
[client.radosgw.ttt_40_111]
    host = ttt_40_111
    user = root
    keyring = /etc/ceph/ceph.client.radosgw.keyring
    rgw host = 0.0.0.0
    rgw port = 8001
    log file = /var/lib/ceph/radosgw/radosgw.log
    rgw print continue = false
    debug rgw = 1

[client.radosgw.ttt_98_111]
    host = ttt_98_111
    user = root
    keyring = /etc/ceph/ceph.client.radosgw.keyring
    rgw host = 0.0.0.0
    rgw port = 8001
    log file = /var/lib/ceph/radosgw/radosgw.log
    rgw print continue = false
    debug rgw = 1
```

## 生成 keyring
分别在2台机器上执行命令生成 keyring
```sh
ceph-authtool --create-keyring /etc/ceph/ceph.client.radosgw.keyring
ceph-authtool -n client.radosgw.ttt_98_111 \
  --gen-key /etc/ceph/ceph.client.radosgw.keyring
ceph-authtool -n client.radosgw.ttt_98_111 \
  --cap osd 'allow rwx' --cap mon 'allow rw' --cap mds 'allow rw' \
  /etc/ceph/ceph.client.radosgw.keyring
```
分别在2台机器上执行，将 radosgateway 的 keyring 加到 ceph 集群的 keyring 中：
```sh
ceph -k /etc/ceph/ceph.client.admin.keyring auth add \
  client.radosgw.ttt_98_111 -i /etc/ceph/ceph.client.radosgw.keyring
```
> 因为在添加时需要拥有 ceph 集群的 admin key，方能有权限操作 ceph 集群，所以事先找个2台就是能够访问 ceph 的，其它机器的话再单独配置 admin key 访问权限即可

## 启动 radosgw
```sh
# @后面是ceph.conf中[client.radosgw.ttt_98_111]里除了client 的后面部分
systemctl restart ceph-radosgw@radosgw.ttt_98_111
systemctl status ceph-radosgw@radosgw.ttt_98_111 # 查看状态
```
检查端口 `netstat -tunlp | grep radosgw`，输出如下：
```
tcp 0 0 0.0.0.0:7480 0.0.0.0:* LISTEN 48269/radosgw
tcp 0 0 0.0.0.0:8001 0.0.0.0:* LISTEN 48269/radosgw
```
一般只会输出 7480，但我们配置中加了8001这个，其目的就是为了后面 nginx 的转发到这个端口


## 配置 nginx
增加 /usr/local/nginx/conf/vhosts/rgw.conf，内容如下：
```
upstream bk_radosgw
{
    server ttt_40_111:8001;
    server ttt_98_111:8001;
}

server
{
    listen *:8080;
    location /
    {
        include fastcgi_params;
        fastcgi_pass_header Authorization;
        fastcgi_pass_request_headers on;
        fastcgi_pass bk_radosgw;
    }
}
```

创建 rgw 使用的用户并授权
```sh
radosgw-admin user create --uid=fe.ceph --display-name=fe.ceph # 名字叫 fe.ceph
radosgw-admin caps add --uid=fe.ceph --caps="users=read, write"
radosgw-admin caps add --uid=fe.ceph --caps="usage=read, write"
radosgw-admin user info --uid=fe.ceph # 查看 access_key
```

调用示例
`curl 10.153.44.42:8080/fe.ceph/user?format=json` 其中 10.153.44.42 为启动的 nginx 机器，正常返回如下示：
```json
{
    "Code":"NoSuchBucket",
    "BucketName":"fe.ceph",
    "RequestId":"tx000000000000000000005-005a97d0ef-20bcef-default",
    "HostId":"20bcef-default-default"
}
```

## 性能提升
如果性能不高的话，原因是 ceph RGW 在写大量文件时, 写 index 成了磁盘 io 瓶颈，解决方法是将 index 进行分片，修改配置文件, 开启 index 分片(/etc/ceph/ceph.conf):
```
[global]
...
rgw_override_bucket_index_max_shards=8
```
重启rgw
```
sudo systemctl restart ceph-radosgw＠×××
```
