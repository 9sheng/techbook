# Ceph 客户端安装及 RBD 挂载

## 安装 ceph 客户端
使用命令 `modprobe rbd` 确认内核是支持 rbd，如不支持考虑升级内核

联系 ceph 管理员安装 ceph 客户端，获取 ceph 用户名以及权限文件 ceph.client.rbd.keyring，将权限文件放到 `/etc/ceph` 目录下

执行命令 `ceph -s --id rbd # 用户名为 rdb`，如果命令正常输出，表明此 client 所在机器可以访问并使用 ceph 集群

## RBD 块存储映射
设置完本地访问 ceph 的认证权限外，需要将本地指定目录挂载与 ceph 提供的 rbd 镜像地址进行关联，以便开发的服务可以写本地指定的目录（目录会自动同步到 ceph 存储集群）挂载步骤如下：

### 挂载 rbd
1. 与 ceph 管理员沟通，所使用服务的业务需求：如资源池名称 pool-name、镜像名称 image-name、副本数、空间大小等
1. 建立映射，客户端机器上执行 `rbd map ${pool-name}/${image-name} --id rbd`，执行完毕后会输出类似于 `/dev/rbd0` （类似rbd0，rbd1…本地可以生成多份映射关系）
1. 执行 `mkfs.xfs /dev/rbd0` 进行文件系统初始化（**初始化为 xfs 格式即可，只有在第一次使用时需要格式化，再次格式化会丢失数据**）
1. 本地创建目录 `mkdir /data/yourapp`  （即应用程序读写数据或日志目录）
1. 本地目录与 rbd 对应 ceph 集群进行映射关联，执行 `mount /dev/rbd0 /data/yourapp`

至此，在此客户端机器上即可安装服务，服务对 `/data/yourapp` 目录的所有操作（文件操作等）都会同步到 ceph 集群，当本地机器故障后，可以另一台 client 上重新设置并部分服务，其对应原来机器操作的数据不会丢失可以继续使用。

### 自动挂载设置
设置自动 map，修改 `/etc/ceph/rbdmap`，增加如下内容：
```
rbd/test1 id=rbd,keyring=/etc/ceph/ceph.client.rbd.keyring
```

自动挂载块设备，在 `/etc/fstab` 增加如下内容：
```
/dev/rbd/rbd/test1 /mnt/rbd-test1 xfs defaults,noatime,_netdev 0 0
```

设置 rbdmap 开机启动 `systemctl enable rbdmap`
> 设置开机启动后，磁盘总是挂载不上，发现 `systemctl is-enable rbdmap` 是 static 状态，不是 enable，经查，这里的 static 是指 Unit 的文件中没有 [Install] 区域，因此需要添加此区域，即 `/usr/lib/systemd/system/rbdmap.servic` 中增加如下内容：
```
[Install]
WantedBy=multi-user.target
```
重启机器 `reboot` 或 `systemctl restart rbdmap`


## 附：管理员操作
### 创建 pool
```sh
ceph osd pool create rbd 64
ceph osd pool application enable rbd rbd
ceph osd pool set rbd size 3 # 设置副本数为 3
```

### 生成客户端 keyring
```sh
ceph auth get-or-create client.rbd -o ./ceph.client.rbd.keyring  # 导出秘钥
ceph auth caps client.rbd mon 'allow r' osd 'allow rwx pool=rbd' # 修改权限
```
ceph.client.rbd.keyring 如下：
```
[client.rbd]
    key = AQD+Qo5cdS0mOBAA6bPb/KKzSkSvwCRfT0nLXA==
    caps mon = "allow r"
    caps osd = "allow rwx pool=rbd"
```

### 创建 image
```sh
rbd create --size 1024 foo   # 创建 rbd image
```

参考：https://www.cnblogs.com/zyxnhr/p/10549727.html
