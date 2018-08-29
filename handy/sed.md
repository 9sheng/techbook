# sed 常用命令

删除：d命令
```sh
sed '2,$d' example # 删除example文件的第二行到末尾所有行
sed '/test/d' example # 删除example文件所有包含test的行
```

替换：s命令
```sh
# 如果某一行开头的test被替换成mytest，打印
sed -n 's/^test/mytest/p' example
# 所有以192.168.0.1开头的行变成192.168.0.1localhost
sed 's/^192.168.0.1/&localhost/' example
# love被标记为1，所有loveable会被替换成lovers
sed -n 's/\(love\)able/\1rs/p' example
# 紧跟着s命令的都被认为是新的分隔符，“#”在这里是分隔符
sed 's#10#100#g' example
```

选定行的范围：逗号
```sh
# 所有在模板test和check所确定的范围内的行都被打印
sed -n '/test/,/check/p' example
# 打印从第五行开始到第一个包含以test开始的行之间的所有行
sed -n '5,/^test/p' example
# 对于模板test和check之间的行，每行的末尾用字符串sed test替换
sed '/test/,/check/s/$/sed test/' example
```

多点编辑：e命令
```sh
# 命令的执行顺序对结果有影响
sed -e '1,5d' -e 's/test/check/' example
sed --expression='s/test/check/' --expression='/love/d' example
```

从文件读入：r命令
```sh
# file里的内容被读进来，显示在与test匹配的行后面
sed '/test/r file' example
# insert file into example after line 2
sed '2r file' example
```

写入文件：w命令
```sh
# 在example中所有包含test的行都被写入file里
sed -n '/test/w file' example
```

追加命令：a命令
```sh
# 追加到以test开头的行后面，sed要求命令a后面有一个反斜杠
sed '/^test/a\this is an appended line' example
```

插入：i命令
```sh
# 如果test被匹配，则把反斜杠后面的文本插入到匹配行的前面
sed '/test/i\this is an inserted line' example
```

下一个：n命令
```sh
# 如果test被匹配，则移动到匹配行的下一行，替换这一行的aa，变为bb，并打印该行，然后继续
sed '/test/{n; s/aa/bb/;}' example
```

变形：y命令
```sh
# 把1--10行内所有abcde转变为大写，注意，正则表达式元字符不能使用这个命令
sed '1,10y/abcde/ABCDE/' example
```

退出：q命令
```sh
# 打印完第10行后，退出sed
sed '10q' example
```

保持和获取：h命令和G命令。在sed处理文件的时候，每一行都被保存在一个叫模式空间的临时缓冲区中，除非行被删除或者输出被取消，否则所有被处理的行都将打印在屏幕上。接着模式空间被清空，并存入新的一行等待处理。在这个例子里，匹配test的行被找到后，将存入模式空间，h命令将其复制并存入一个称为保持缓存区的特殊缓冲区内。第二条语句的意思是，当到达最后一行后，G命令取出保持缓冲区的行，然后把它放回模式空间中，且追加到现在已经存在于模式空间中的行的末尾。在这个例子中就是追加到最后一行。
```sh
# 任何包含test的行都被复制并追加到该文件的末尾
sed -e '/test/H' -e '$G' example
```

保持和互换：h命令和x命令
```sh
# 互换模式空间和保持缓冲区的内容。也就是把包含test与check的行互换
sed -e '/test/h' -e '/check/x' example
```

sed的选项：
- `-e command, --expression=command` 允许多台编辑
- `-n, --quiet, --silent` 取消默认输出

sed定位的方法：
- `x` x为指定行号
- `x,y` 指定从x到y的行号范围
- `/pattern/` 查询包含模式的行
- `/pattern/pattern/` 查询包含两个模式的行
- `/pattern/,x` 从与pattern的匹配行到x号行之间的行
- `x,/pattern/` 从x号行到与pattern的匹配行之间的行
- `x,y!` 查询不包含x和y行号的行

sed编辑命令表：
- `p` 打印匹配行
- `=` 打印匹配行号
- `a\` 在定位行之后追加文本信息
- `i\` 在定位行之前插入文本信息
- `d` 删除定位行
- `c\` 用新文本替换定位行
- `s` 使用替换模式替换相应的模式
- `r file` 从另一个文件中读文本
- `w file` 将文本写入到另一个文件中
- `y` 变换字符
- `q` 第一个模式匹配完成后退出
- `l` 显示与八进制ASCII码等价的控制字符
- `{}` 在定位行执行的命令组
- `n` 读取下一个输入行，用下一个命令处理新的行
- `h` 将模式缓存区的文本复制到保持缓存区
- `H` 将模式缓存区的文本追加到保持缓存区
- `x` 互换模式缓存区和保持缓存区的内容
- `g` 将保持缓存区的内容复制到模式缓存区
- `G` 将保持缓存区的内容追加到模式缓存区
