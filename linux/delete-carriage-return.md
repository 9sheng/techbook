# 删除Linux中的^M

很久以前，老式的电传打字机使用两个字符来另起新行。一个字符把滑动架移回首位（称为回车 *CR* ），另一个字符把纸上移一行（称为换行 *LF* ）。当计算机问世以后，存储器曾经非常昂贵。有些人就认定没必要用两个字符来表示行尾。

UNIX 开发者决定他们可以用一个字符来表示行尾，Linux 沿袭 Unix，也是 =\n= 。
Apple 开发者规定了用 =\r= 开发 MS-DOS 以及 Windows 的那些家伙则决定沿用老式的。

三种行尾格式如下:

| 系统 | 名称     | 转义   |  ASCII |
|------|----------|--------|--------|
| mac  | 回车     | =\r=   |    0xa |
| unix | 换行     | =\n=   |    0xd |
| dos  | 回车换行 | =\r\n= | 0xa0xd |

这意味着，如果你试图把一个文件从一种系统移到另一种系统，那么你就有换行符方面的麻烦。
因为 MS-DOS 及 Windows 是回车＋换行来表示换行，因此在 Linux 下查看在 Windows 下写的代码，
行尾 `^M` 符号，可用以下命令查看： `cat -A filename` , vi 中可以 `:set list`

在 Vim 中解决这个问题，很简单，在 Vim 中利用替换功能就可以将 `^M` 都删掉，
键入如下替换命令 `:%s/^M//g` 或者 `:%s/\r//g` 。
注意：上述命令行中的 `^M` 由 `C-v C-M` 生成。

或者使用这个命令:
```sh
dos2unix filename
```
或者
```sh
sed -i 's/^M//g' filename # 注意：^M的输入方式是 Ctrl + v ，然后Ctrl + M
```
或者
```sh
cat filename | tr -d '\r' > newfile #^M 可用 \r 代替
```
Emacs 中替换
```sh
C-x RET c undecided-unix RET C-x C-w RET y
M-S < # 到文档的最开始处
M-x replace-string RET C-q C-m RET RET
```
注意上面的 `C-q C-m` 就是换行符的生成方法，而不是简单的输入 `^M`
