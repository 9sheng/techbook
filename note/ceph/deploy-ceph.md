# 使用 ceph-deploy 部署 ceph 集群

## 1. 环境准备

将 https://download.ceph.com/rpm-luminous/el7/x86_64/ 上某一版本的所有 rpm 下载到本地，并制作 yum 本地安装源，并复制到所有 ceph 节点上。
> 以下步骤每个 ceph 节点机器上都需要执行

### 增加 ceph 源
源文件 `/etc/yum.repos.d/ceph.repo`，内容如下：
```
[ceph]
name=ceph
baseurl=file:///home/cepher/ceph-12.2.5
enabled=1
gpgcheck=0
priority=1
```

### 增加 epel 源
EPEL (Extra Packages for Enterprise Linux)是基于Fedora的一个项目，为“红帽系”的操作系统提供额外的软件包，适用于 RHEL、CentOS 和 Scientific Linux。

源文件 `/etc/yum.repos.d/epel.repo`，内容如下：
```
[epel-7-epel]
name=Mirror of epel-7-epel
baseurl=http://repo.sogou/pub/repo.epel/7/$basearch/epel
gpgcheck=0
cost=2000
enabled=1

[epel-7-epel-source]
name=Mirror of epel-7-epel-source
baseurl=http://repo.sogou/pub/repo.epel/7/$basearch/epel-source
gpgcheck=0
cost=2000
enabled=1
```

### 设置 hostname
Cluster Map 中会使用主机 hostname 作为名称表示，因此 hostname 需要好好规划。
```
192.168.1.1 admin-node
192.168.1.2 node1 # 主机名也要改为 node1
192.168.1.3 node2
192.168.1.4 node3
```

### 配置 NTP
保证所有 ceph 节点的时间都是同步的，各 osd 节点间需要设置时间同步，节点时钟偏差过大会引起 pg 异常。

### 关闭 iptables 和 selinux

## 2. 安装 ceph-deploy 工具
ceph-deploy 是 ceph 官方提供的部署工具，它通过 ssh 远程登录其它各个节点上执行命令完成部署过程，在 admin-node 节点安装 ceph-deploy 命令，并配置 admin-node 到**所有ceph节点** 的 ssh 秘钥登录
```sh
yum install ceph-deploy –y
ssh-keygen
ssh-copy-id
```
> 在某些发行版（如 CentOS ）上，执行 ceph-deploy 命令时，如果 ceph 节点默认设置了 requiretty 那就会遇到报错。可以这样禁用此功能：执行 sudo visudo ，找到 `Defaults requiretty` 选项，把它改为 `Defaults:ceph !requiretty`

## 3. 安装 ceph 集群
在执行 ceph-deploy 的过程中会生成一些配置文件，建议在 admin-node 节点创建一个目录，例如 my-cluster。
```sh
mkdir /home/cepher/my-cluster
cd /home/cepher/my-cluster
```
> 下面的部署操作都要在 my-cluster 目录下操作

### 创建 ceph 集群
```sh
ceph-deploy new node1 node2 node3 # 不要重复执行该命令，会生成新的秘钥环
# 默认ceph使用集群名ceph，可以使用下面命令创建一个指定的ceph集群名称
# ceph-deploy --cluster {cluster-name} new {host [host], ...}
```
my-cluster 目录下应该有一个 ceph 配置文件、一个 monitor 密钥环和一个日志文件。修改刚生成的配置文件，在 ceph.conf 中加入：
```
osd pool default size = 2             # 默认副本数从 3 改成 2
mon osd down out interval = 0         # 关闭自动迁移
mon osd down out subtree limit = host # 不进行自动迁移的最小 bucket
osd pool default min size = 1         # I/O 不阻塞的最小副本数，默认是 0
osd pool default pg num = 128         # pool 的 pg 数量
osd pool default pgp num = 128        # pool 的 pgp 数量
public network = 192.168.1.0/24       # 公共网络
cluster network = 192.168.1.0/24      # 集群网络
```
> 注意 ceph.conf 配置文件中的参数名称如果带有 default 则表示是默认设置，它不会立即生效，而是在你创建新的 pool 或其他东西的时候才生效，而一般名称中没有 default 的可能是全局参数，push 之后立即生效

### 安装 ceph 组件
使用 `--no-adjust-repos` 参数忽略设置 ceph 源
```sh
ceph-deploy install node1 node2 node3 --no-adjust-repos
```

### 初始化 moniter 节点
```sh
ceph-deploy mon create-initial

# 上面命令效果如下
# 1.write cluster configuration to /etc/ceph/{cluster}.conf
# 2.生成/var/lib/ceph/mon/ceph-node1/keyring
# 3.systemctl enable ceph-mon@node1
# 4.systemctl start ceph-mon@node1
```
### 初始化 OSD 节点
创建 OSD
```sh
ceph-deploy osd prepare node2:sdb:sdc node3:sdb:sdc # 创建 GPT 分区、创建文件系统
ceph-deploy osd activate node2:sdb:sdc node3:sdb:sdc # 激活 OSD
```
> 以上两条命令可以直接用 `ceph-deploy osd create node2:sdb:sdc node3:sdb:sdc` 这条命令代替
> 如果不是以一整块盘为一个 osd 而是以一个分区为一个 osd 的话，就需要提前手动分好区（包括日志盘或分区，注意分区时要保证分区对齐，建议从1M处开始分）
> `node2:sdb1:sdc` 中sdb1表示osd，sdc表示该osd的日志盘，也可以不指定日志盘，与osd共享空间，即node2:sdb1，此时不能用ceph-deploy osd create命令代替prepare和activate

将各节点的 ceph 磁盘挂载目录（/var/lib/ceph/osd/ceph-xx）添加到 `/etc/fstab` 中

### 安装 mgr 服务
luminous 版需要安装 mgr 服务，ceph-mgr 目前的主要功能是把集群的一些指标暴露给外界使用，在 monitor 节点上装 mgr 服务：
```sh
ceph-deploy mgr create monitor-node
```

## 4. 其他
允许一主机以管理员权限执行 ceph 命令
```sh
ceph-deploy admin {host-name [host-name]...}
# 拷贝 ceph.conf 和 client.admin.keyring 到远程主机上
```

把改过的配置文件分发给集群内各主机
```sh
ceph-deploy --overwrite-conf config push node{1..3}
```

清除磁盘操作
```sh
# 查看某节点上所有磁盘
ceph-deploy disk list {node-name [node-name]...}
# 清除指定磁盘上的分区，用于重装ceph集群
ceph-deploy disk zap {osd-server-name}:{disk-name}
ceph-deploy disk zap node1:/dev/vdb
```

monitor 操作
```sh
# 从某个节点上移除 mon 进程
ceph-deploy mon destroy {host-name [host-name]...}
```
