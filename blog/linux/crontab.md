# linux计划任务crontab

> Cron is a time-based job scheduler in Unix-like computer operating systems. The name cron comes from the world chronograph(a time-piece).

crontab 配置格式如下：
```
.----------- minute (0 - 59)
| .--------- hour (0 - 23)
| | .------- day of month (1 - 31)
| | | .----- month (1 - 12) OR jan,feb,mar,apr …
| | | | .--- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
| | | | |
* * * * * command to be executed
```

**必须使用的一则技巧**：  
每条 JOB 执行完毕之后，系统会自动将输出发送邮件给当前系统用户。日积月累，非常的多，甚至会撑爆整个系统。所以每条 JOB 命令后面进行重定向处理是非常必要的： `>/dev/null 2>&1` 。前提是对 Job 中的命令需要正常输出已经作了一定的处理, 比如追加到某个特定日志文件。

# 1.直接用 crontab 命令编辑
cron 服务提供 crontab 命令来设定 cron 服务的，以下是这个命令的一些参数与说明：
```sh
crontab -u // 设定某个用户的cron 服务，一般 root 用户在执行这个命令的时候需要此参数
crontab -l // 列出某个用户 cron 服务的详细内容
crontab -r // 删除没个用户的 cron 服务
crontab -e // 编辑某个用户的 cron 服务
```

比如说root查看自己的cron设置：
```sh
crontab -u root -l
```
再例如，root想删除fred的cron设置：
```sh
crontab -u fred -r
```

在编辑cron服务时，编辑的内容有一些格式和约定，输入：
```sh
crontab -u root -e
```

进入vi编辑模式，编辑的内容一定要符合下面的格式：
```sh
*/1 * * * * ls >> /tmp/ls.txt
```

这个格式的前一部分是对时间的设定，后面一部分是要执行的命令，如果要执行的命令太多，可以把这些命令写到一个脚本里面，然后在这里直接调用这个脚本就可以了，调用的时候记得写出命令的完整路径。时间的设定我们有一定的约定，前面五个*号代表五个数字，数字的取值范围和含义如下：

分钟　（0-59）
小時　（0-23）
日期　（1-31）
月份　（1-12）
星期　（0-6）//0代表星期天

除了数字还有几个个特殊的符号就是“\*”、“/”和“-”、“,”，\*代表所有的取值范围内的数字，“/”代表每的意思,“*/5”表示每5个单位，“-”代表从某个数字到某个数字,”,”分开几个离散的数字。以下举几个例子说明问题：

每天早上6点
```
0 6 * * * echo “Good morning.” >> /tmp/test.txt //注意单纯echo，从屏幕上看不到任何输出，因为 cron 把任何输出都 email 到 root 的信箱了。
```
每两个小时
```
0 */2 * * * echo “Have a break now.” >> /tmp/test.txt
```
晚上11点到早上8点之间每两个小时，早上八点
```
0 23-7/2，8 * * * echo “Have a good dream：）” >> /tmp/test.txt
```
每个月的4号和每个礼拜的礼拜一到礼拜三的早上11点
```
0 11 4 * 1-3 command line
```
1月1日早上4点
```
0 4 1 1 * command line
```
每次编辑完某个用户的 cron 设置后，cron 自动在 /var/spool/cron下生成一个与此用户同名的文件，此用户的 cron 信息都记录在这个文件中，这个文件是不可以直接编辑的，只可以用 crontab -e 来编辑。cron 启动后每过一份钟读一次这个文件，检查是否要执行里面的命令。因此此文件修改后不需要重新启动 cron 服务。

### 2.编辑 /etc/crontab 文件配置 cron

cron 服务每分钟不仅要读一次 /var/spool/cron 内的所有文件，还需要读一次 /etc/crontab，因此我们配置这个文件也能运用 cron 服务做一些事情。用 crontab 配置是针对某个用户的，而编辑 /etc/crontab 是针对系统的任务。此文件的文件格式是：
```sh
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root //如果出现错误，或者有数据输出，数据作为邮件发给这个帐号
HOME=/ //使用者运行的路径,这里是根目录
# run-parts
01 * * * * root run-parts /etc/cron.hourly  // 每小时执行/etc/cron.hourly内的脚本
02 4 * * * root run-parts /etc/cron.daily   // 每天执行/etc/cron.daily内的脚本
22 4 * * 0 root run-parts /etc/cron.weekly  // 每星期执行/etc/cron.weekly内的脚本
42 4 1 * * root run-parts /etc/cron.monthly // 每月去执行/etc/cron.monthly内的脚本
```

大家注意“run-parts”这个参数了，如果去掉这个参数的话，后面就可以写要运行的某个脚本名，而不是文件夹名了。

怎样在 unix 系统下查看所有用户的 crontab 的定时任务？
```sh
grep -v "^#" /var/spool/cron/crontabs/*
```
 
