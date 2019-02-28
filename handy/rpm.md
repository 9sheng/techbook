# rpm

```sh
rpm -ivh  # 安装显示安装进度--install--verbose--hash
rpm -Uvh  # 升级软件包 --Update
rpm -qpl  # 列出RPM软件包内的文件信息[Query Package list]
rpm -qpi  # 列出RPM软件包的描述信息[Query Package install package(s)]
rpm -qf   # 查找指定文件属于哪个RPM软件包[Query File]
rpm -Va   # 校验所有的RPM软件包，查找丢失的文件[View Lost]
rpm -e    # 删除包

rpm2cpio kernel-debuginfo.rpm | cpio -div # 解压rpm包

# --force 强制操作 如强制安装删除等
# --requires 显示该包的依赖关系
# --nodeps 忽略依赖关系并继续操作
```
