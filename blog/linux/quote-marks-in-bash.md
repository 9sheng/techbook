# bash 里面的引号

## 单引号' '
目的: 为了保护文字不被转换.除了他本身. 就是说除去单引号外, 在单引号内的所有文字都是原样输出.

<!-- more -->

	echo '$*><!'

输出：$*><!

	echo 'she is crying: "help"'

输出：she is crying: "help"

	echo '\\\\'

输出：\\\\

	echo 'hah 'test''

输出：hah test # 略去了所有'

	echo ' today is `date`'

输出：today is `date` # 反引号在此无法实现函数功能.

 

## 双引号" "
目的: 为了包含文字或者函数段. 除了本身,反引号内的函数,$开头的变量和\\开头反转换的字符外, 其余都是直接输出.

	echo "today is `date`"

输出：today is Fri Jul 4 08:03:34 GMT 2008

	echo "today is 'date'" 

输出：today is 'date'# 直接输出单引号

	echo "\\\\"

输出：\\

	echo "test "test""

输出：test test

## 反引号` `
目的: 是为了在双引号内保持函数转换. 但单引号内其无作用.

	echo "today is `date`"

输出：today is Fri Jul 4 08:03:34 GMT 2008

	echo ' today is `date` '

输出：today is `date` # 在单引号内无作用.

 
## 附
如何输出 abc'abc

	echo 'abc'\''abc'
	echo -e 'abc\x27abc'
	echo $'abc\'abc' # bash特有

