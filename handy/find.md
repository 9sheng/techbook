# find 常用

find 命令的基本格式 `find [path] <expression> [operation]`

- `find . -name *.py -maxdepth 1` 查找一级目录下的所有 py 文件
- `find . -ctime -1` 查找 24 小时之内创建的文件，atime 和 mtime 用法一致
- `find . -cmin -10` 查找 10 分钟之内创建的文件，amin 和 mmin 用法一致
- `find . -anewer hello.py` 查找在 hello.py 之后访问过的文件，cnewer 和 mnewer 用法一致
- `find . -user root` 查找属于某一用户的文件
- `find . -type d -name *demo*` 查找所有目录包含 demo 的目录
- `find . -type f -perm -o=x -exec rm {} \;` 查找所有可执行文件，并删除
- `find . -perm 600` 查找权限为 600 的文件，如果权限前面加“-”号，表示满足一位匹配可， `find . -perm -007` 会匹配权限为 007、077、777 的文件
- `find . -empty -ls` 显示所有的空白文件，并显示详细，加 ls 完全画蛇添足，只是为了说明这个参数
- `find . -size +10k -a -size -100k -o -name *demo*` 查找大于 10k 且小于 100k 的文件或者名字含有 demo 的文件
- `find . -size +10k ! -name *demo*` 查找大于 10k 并且名称不含有 demo 的文件
- 用正则表达式查找，匹配时会匹配整个路径，而不仅仅是文件名

使用 grep 正则表达式匹配以数字开头的文件
```sh
find . -regextype grep -regex ".*/[0-9][^/]*"
```