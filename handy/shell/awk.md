# awk 常用命令

## 使用特殊的分隔符
```sh
# 使用正则表达式分割符号，连续多个 ][, 为分割符
awk -F '[],[]*' '{print $2, $12, $14, $16}'
# ascii 码分割符
awk -F '\3' '{if (match($NF,/[0-9]{4}-[0-9]{2}-[0-9]{2}/)) print $NF}'
```

## 将 shell 变量传给 awk
```sh
# 方法一
variable="line one\nline two"
awk 'BEGIN {print "'"$variable"'"}'
# 方法二
awk -v var="$variable" 'BEGIN {print var}'
```

## 在 awk 中调用 shell 命令
```sh
# 例一
awk '{system("wc "$1)}' myfile
# 例二
awk '{
  cmd = "your_command " $1
  while (cmd | getline line) {
    do_something_with(line)
  }
  close(cmd)
}' file
```

gsub 替换，gsub 返回替换次数，源字符串被替换
```sh
date +"%F %T" | awk '{gsub(/[-:]/, " ", $0); tm=mktime($0); print tm}'
```

## 正则匹配
```sh
awk '{if(match($0,/http:\/\/.*\/(.*)\.rpm/,a)) print a[1]}'
```

[酷壳](http://coolshell.cn/articles/9070.html)上的例子:
```sh
# 指定匹配条件
awk '$3==0 && $6=="LISTEN" || NR==1' netstat.txt
# $6 匹配 FIN 或 TIME
awk '$6 ~ /FIN|TIME/ || NR==1 {print NR,$4,$5,$6}' OFS="\t" netstat.txt
# $6 不匹配 WAIT
awk '$6 !~ /WAIT/ || NR==1 {print NR,$4,$5,$6}' OFS="\t" netstat.txt
# 不匹配 WAIT
awk '!/WAIT/' netstat.txt
# 从 file 文件中找出长度大于 80 的行
awk 'length>80' file
# 按连接数查看客户端 IP
netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr
# 打印 99 乘法表
seq 9 | sed 'H;g' | awk -v RS='' \
  '{for(i=1;i<=NF;i++)printf("%dx%d=%d%s", i, NR, i*NR, i==NR?"\n":"\t")}'
```

## 内建变量
- `$0` 当前记录（这个变量中存放着整个行的内容）
- `$1~$n` 当前记录的第n个字段，字段间由FS分隔
- `FS` 输入字段分隔符 默认是空格或Tab
- `NF` 当前记录中的字段个数，就是有多少列
- `NR` 已经读出的记录数，就是行号，从1开始，如果有多个文件话，这个值也是不断累加中。
- `FNR` 当前记录数，与NR不同的是，这个值会是各个文件自己的行号
- `RS` 输入的记录分隔符， 默认为换行符
- `OFS` 输出字段分隔符， 默认也是空格
- `ORS` 输出的记录分隔符，默认为换行符
- `FILENAME` 当前输入文件的名字
