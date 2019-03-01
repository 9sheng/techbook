# shell 脚本

## 常用判断比较
- 逻辑操作符：
`-a` 逻辑与；
`-o` 逻辑或；
`!` 逻辑否
- 字符串比较：
`=` 相等；
`!=` 不等；
`-z` 空串；
`-n` 非空串
- 数值比较：
`-eq`
`-ne`
`-gt`
`-lt`
`-le`
`-ge`

文件状态：
`-d` 目录；
`-f` 正规文件；
`-L` 符号链接；
`-r` 可读；
`-w` 可写；
`-x` 可执行；
`-s` 文件非空；
`-u` 文件有suid位设置

## 脚本路径
```sh
echo "scriptPath1: " $(cd `dirname $0`; pwd)
echo "scriptPath2: " $(dirname $(readlink -f $0))
```

## 进程文件锁
有些脚本运行时，只允许一个实例，使用文件锁，代码如下，只需要在脚本开始处调用 `lock_file`
```sh
lock_file() {
  THIS_NAME=`basename $0`
  #clear invalid symbolic link first.
  find /dev/shm -maxdepth 1 -type l -follow -exec unlink {} \;
  #check whether another shell script is running.
  if [ -e /dev/shm/$THIS_NAME ]; then
    echo "exit as previous task is still running: $THIS_NAME"
    exit 0
  fi

  ln -s /proc/$$ /dev/shm/$THIS_NAME
  trap "exit_lock" 0 1 2 3 15 22 24
}

function exit_lock()
{
unlink /dev/shm/$THIS_NAME
exit 0
}
```

## 后台job
在脚本中启动后台进程，并等待结果
```sh
for ((i = 0; i < ${JOB_NUM}; i++)); do
  (get_files $i)&
done

for ((i = 0; i < ${JOB_NUM}; i++)); do
  j=$(($i+1))
  wait %$j
  if [ $? -ne 0 ]; then logger_error "fetch files ${prefix} failed" exit -1 fi
done
```

## 数值计算
```sh
declare -i TOTAL=15;
for ((id=1; id < TOTAL; id++)); do  # id+=1 也可以
  if (( id % 3 == 0 )); then
    continue
  fi
  t=`printf '%02d' $id`
  echo "dubhe$t"
done
```

`let` does exactly what `(( ))` do.
```sh
CPUs=$(grep -c processor /proc/cpuinfo)
PIDs=$(ps aux | grep "php-fpm[:] pool" | awk '{print $2}')

let i=0
for PID in $PIDs; do
  CPU=$(echo "$i % $CPUs" | bc)
  taskset -pc $CPU $PID
  let i++
  #or, let i+=1
done
```
## 参数扩展
| 命令               | 说明                                                                          |
|--------------------|-------------------------------------------------------------------------------|
| `${name:-default}` | 使用一个默认值（一般是空值）来代替那些空的或者没有赋值的变量name              |
| `${name:=default}` | 使用指定值来代替空的或者没有赋值的变量name                                    |
| `${name:?message}` | 如果变量为空或者未赋值，那么就会显示出错误信息并中止脚本的执行同时返回退出码1 |
| `${#name}`         | 给出name的长度                                                                |
| `${name%word}`     | 从name的尾部开始删除与word匹配的最小部分，然后返回剩余部分                    |
| `${name%%word}`    | 从name的尾部开始删除与word匹配的最长部分，然后返回剩余部分                    |
| `${name#word}`     | 从name的头部开始删除与word匹配的最小部分，然后返回剩余部分                    |
| `${name##word}`    | 从name的头部开始删除与word匹配的最长部分，然后返回剩余部分                    |

- 检查变量是否存在 `${name:?error message}`
- 如果脚本需要一个参数 `input_file=${1:?usage: $0 input_file}`
- 截断字符串 `${var%suffix}` 和 `${var#prefix}`
`var=foo.pdf; echo ${var%.pdf}.txt` 输出：foo.txt
- dirname
`a=/home/aguo/insert.sql; echo ${a%/*}` 输出：/home/aguo
- basename
`a=/home/aguo/insert.sql; echo ${a%%.*}` 输出：/home/aguo/insert
- 只取 name
`a=/home/aguo/insert.test.sql; a=${a%%.*} && a=${a##*/} && echo $a` 输出：insert

## subshell
临时地到另一个目录中：
```sh
# do something in current dir
(cd /some/other/dir; other-command)
# continue in original dir
```

## 调试
- 使用 `set -x` 来 debug 输出
- 使用 `set -e` 来当有错误发生的时候 abort 执行
- 使用 `set -o pipefail` 来限制错误
- 使用 `trap` 来截获信号（如截获ctrl+c）

只调试部分脚本，在想要调试的脚本之前调用 `set -x` ，结束的时候调用 `set +x` 。如下所示：
```sh
#!/bin/bash
echo "Hello $USER,"
set -x
echo "Today is $(date %Y-%m-%d)"
set +x
```
