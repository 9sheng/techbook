# grep 常用命令

```sh
grep [option] 'pattern string' filename
```

高亮匹配结果，并过滤 .git .svn 等文件夹。
```sh
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
```

显示 `/etc/inittab` 中以 # 开头，且后面跟一个或者多个空白符，而后又跟了任意非空白符的行
```sh
grep '#[[:space:]]*[^[:space:]]' /etc/inittab
```

`egrep` 命令等同于 `grep -E` ，利用此命令可以使用扩展的正则表达式对文本进行搜索，下面三条命令是等价的，列出当前目录（包括子目录）中查找所有包含 UA 或 DL 的文件
```sh
grep -r -l "\(UA\)\|\(DL\)" ./
grep -r -l -E "(UA)|(DL)" ./
egrep -r -l "(UA)|(DL)" ./
```

查找行首是 1 或 2，后面是 rc 中间接任意字符而后跟 /rc
```sh
egrep '^(1|2).*(rc).*/\1.*' /etc/inittab
```

查找含有非 ascii 字符的文件，并显示行
```sh
grep --color=auto -P -n "[\x80-\xFF]" file.txt
```


查找特殊字符 TAB，详细见[这里](http://askubuntu.com/questions/53071/how-to-grep-for-tabs-without-using-literal-tabs-and-why-does-t-not-work)
```sh
grep -P "\t" foo.txt # 使用 perl 正则表达样
grep "$(printf '\t')" foo.txt
grep "^V<tab>" foo.txt
grep $'\t' foo.txt
```

查找含有 success 的行，并显示上下几行
```sh
grep -A "success" foo.txt # 显示前 4 行
grep -B "success" foo.txt # 显示后 4 行
grep -C "success" foo.txt # 显示前、后 4 行
```

grep *正则表达式* 简介如下：
- `^` 锚定行首； `$` 锚定行尾
- `.`匹配一非换行符字符； `*` 匹配零个或多个先前字符
- `[]` 匹配一个指定范围内的字符； `[^]` 匹配一个不在指定范围内的字符
- `/(../)` 标记匹配字符
- `/<` 锚定单词开始； `/>` 锚定单词结束
- `x/{m/}` 重复字符x，m次； `x/{m,/}` 重复字符x,至少m次； `x/{m,n/}` 重复字符x，至少m次，不多于n次
- `/w` 匹配文字和数字字符，也就是 `[A-Za-z0-9]` ； `/W` 为 `/w` 的反置形式，匹配一个或多个非单词字符
- `/b` 单词锁定符

*扩展的正则表达式* 基本正则表达式使用 `( ) { } . ? |` 都需要转义，在扩展正则表达中不需要转义；另外扩展的正则表达式还加入了至少出现一次 `+` 、或者 `|` 。详细信息如下：
- 字符匹配的命令和用法与基本正则表达式的用法相同
- 字符锚定的用法和基本正则表达式的用法相同
- 次数匹配：
- `*` 匹配其前面字符的任意次
- `?` 匹配其前面字符的 0 或 1 次
- `+` 匹配其前面字符至少 1 次
- `{m,n}` 匹配其前面字符 m 到 n 次
- 特殊字符：
- `|` 代表或者 `grep -E 'c|cat' file` 表示在文件 file 内查找包含 c 或者 cat
- `\.` \表示转义字符，此表示符号 `.`

*POSIX字符类* POSIX增加了特殊的字符类，如 `[:alnum:]` 是 `A-Za-z0-9` 的另一个写法，要把它们放到[]号内才能成为正则表达式。在linux下的grep除fgrep外，都支持POSIX的字符类。
- `[:alnum:]` 文字数字字符
- `[:alpha:]` 文字字符
- `[:digit:]` 数字字符
- `[:graph:]` 非空字符（非空格、控制字符）
- `[:lower:]` 小写字符
- `[:cntrl:]` 控制字符
- `[:print:]` 非空字符（包括空格）
- `[:punct:]` 标点符号
- `[:space:]` 所有空白字符（新行，空格，制表符）
- `[:upper:]` 大写字符
- `[:xdigit:]` 六进制数字（0-9，a-f，A-F）