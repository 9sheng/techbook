# Linux Core 基础

# 开启
`ulimit -a` 可以检查生成core文件的选项是否打开，该命令将显示所有的用户定制，其中选项 `-a` 代表 all 。也可以修改系统文件来调整 core 选项，在 `/etc/profile` 通常会有这样一句话来禁止产生 core 文件 `ulimit -c 0` 。

在开发过程中为了调试问题，需要在特定的用户环境下打开 core 文件产生的设置，可在用户的 `~/.bash_profile` 里加上 `ulimit -c unlimited` 让特定的用户可以产生 core 文件；而 `ulimit -c 1024` 则限制产生的 core 文件的大小不能超过 1024kb。

# 命名
- /proc/sys/kernel/core_uses_pid : 控制产生的 core 文件的文件名中是否添加 pid 作为扩展，如果添加则文件内容为 1 ，否则为 0
- /proc/sys/kernel/core_pattern : 设置格式化的 core 文件保存位置或文件名

core 文件会存放到 `/corefile` 目录下，产生的文件名为"core-命令名-pid-时间戳"：
```sh
echo "/corefile/core-%u-%e-%p-%t" > /proc/sys/kernel/core_pattern
```

参数列表：

| 参数 | 说明                                                             |
|------|------------------------------------------------------------------|
| `%p` | insert pid into filename 添加pid                                 |
| `%u` | insert current uid into filename 添加当前uid                     |
| `%g` | insert current gid into filename 添加当前gid                     |
| `%s` | insert signal that caused the coredump into the filename 信号    |
| `%t` | insert UNIX time that the coredump occurred into filename 时间   |
| `%h` | insert hostname where the coredump happened into filename 主机名 |
| `%e` | insert coredumping executable name into filename 命令名          |

## 使用
使用 `gdb -c core` 来调试 core 文件，会显示生成此 core 文件的程序名，中止此程序的信号等。如果已经知道是什么程序生成此 core 文件的，比如 MyServer 崩溃了生成 core.12345，那么用此指令调试: `gdb -c core MyServer` 。

## 测试
直接输入指令: `kill -s SIGSEGV`
