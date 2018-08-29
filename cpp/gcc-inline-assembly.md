# 从CAS到内嵌汇编

## 引子
从博文《[无锁队列的实现](http://coolshell.cn/articles/8239.html)》里知道了 CAS（Compare & Set，或是 Compare & Swap)，Compare & Swap为例，用C语言描述如下： 
```c
int compare_and_swap(int* reg, int oldval, int newval) {   
  int old_reg_val = *reg;   
  if (old_reg_val == oldval)
      *reg = newval;
  return old_reg_val; 
}
```
`compare_and_swap` 看一看内存 `*reg` 里的值是不是 `oldval`，如果是的话，则对其赋值 `newval`，返回 `*reg` 的旧值。但该操作到底如何实现的，为什么是原子操作，就不得而知了，后来在 [Preshing on Programming](http://preshing.com)、Nginx等好几处又看到这个操作，于是有了“求甚解”的想法，大多数实现都用了嵌入式汇编，于是趁机学习了一下 gcc 的嵌入式汇编。特整理一下，所谓好记性不如烂笔头。

## CAS 实现
先看 nginx 的 CAS 代码：
```c
static ngx_inline ngx_atomic_uint_t
ngx_atomic_cmp_set(ngx_atomic_t *lock, ngx_atomic_uint_t old, ngx_atomic_uint_t set)
{
  u_char  res;
  __asm__ volatile (                    // line 1
  "    lock;               "            // line 2
  "    cmpxchgl  %3, %1;   "            // line 3
  "    sete      %0;       "            // line 4
  : "=a"(res)                           // line 5
  : "m"(*lock), "a"(old), "r"(set)      // line 6
  : "cc", "memory");                    // line 7

  return res;
}
```
首先说说两个汇编指令。第2行的 `lock` 指令，intel 手册上的解释是：
> Causes the processor's LOCK# signal to be asserted during execution of the accompanying instruction (turns the instruction into an atomic instruction). In a multiprocessor environment, the LOCK# signal insures that the processor has exclusive use of any shared memory while the signal is asserted.
意思是 `lock` 将其后续的指令变为一个原子指令，也就是将下面的指令 `cmpxchgl` 变为原子操作。而 `cmpxchgl` 所做动作大概是：
```c
/**
 * accumulator = AL, AX, or EAX, depending on whether
 * a byte, word, or doubleword comparison is being performed
 */
if(accumulator == Destination) {
  F = 1;
  Destination = Source;
} else {
  ZF = 0;
  accumulator = Destination;
}
```
第4行中 `sete cl` 是设置指令，根据 zf(zero flags) 标志位来设置 cl 的值。即是如果 zf=1，则 cl 等于 1，否则等于 0。 综合一下上述两条指令，如果 `cmpxchgl` 更新了 `*reg` 的值， `ngx_atomic_cmp_set` 返回1，否则返回 0。

到现在也只明白了几条汇编指令而已，到底参数是怎么传进去，结果又怎么传出来呢？

## 嵌入汇编

下面简单介绍一下 gcc 嵌入汇编。

最基本的嵌入汇编是这样的 `asm("assembly code");`（注意 AT&T 的汇编语法），如：

```c
asm("movl %ecx %eax"); /* moves the contents of ecx to eax */  
__asm__("movb %bh (%eax)"); /*moves the byte from bh to the memory pointed by eax */
```
其中， `asm` 和 `__asm__` 都是有效的，后者是为了防止关键字冲突。如果我们需要使用一条以上的汇编指令, 每条指令占用一行, 用双引号括起，并加上`\n`和`\t`后缀. 这是因为gcc把用字符串的格式把汇编指令传给as(GAS), 利用换行符转换成正确的汇编格式。举例如下：
```c
__asm__ ("movl %eax, %ebx\n\t"  
         "movl $56, %esi\n\t"  
         "movl %ecx, $label(%edx,%ebx,$4)\n\t"  
         "movb %ah, (%ebx)");  
```

对于复杂的，有输入、输出的嵌入汇编，需要使用扩展模式，刚才的CAS的嵌入式汇编就属于这种情况。扩展模式格式如下：

```c
asm("statement"
    : output_reg(output_variable),  /* optional */
    : input_reg(intpu_variable),    /* optional */
    : colbbered_args);              /* optional */
```

回到最初的代码，从第6行的入参说起，`"m"(*lock), "a"(old), "r"(set)` 表示有三个输入参数，每一个入参都以这样的形式出现：`"constraint"(variable)`（限制 变量）。 `m` 表示 `*lock`是一个内存操作对象， `a` 表示 `old` 需要放到寄存机 eax 中， `r` 表示 gcc 可以自己决定使用哪个寄存器保存变量 `set`。限制 `a`，`b`，`c`，`d`，`S`，`D`，`r` 分别表示 `eax`，`ebx`，`ecx`，`edx`，`esi`，`edi`，`Register(s)`。

`r` 首先将操作数保存在寄存器内，然后在寄存器里进行数据操作，接着把数据写回内存区域。与 `r` 限制符不同，限制符 `m` 后的操作数放在内存中，任何对它们的操作都会直接更改内存值。

第5行中，`"=a"(res)` 是输出参数，即将 eax 的值保存到变量 `res` 中。`=`表示此操作数类型是只写，之前的值会被输出数据值替代。除了 `=` 限制符，还有 `&` 限制符，表示此操作数是一个很早更变的（*earlyclobber*）操作数。在汇编指令使用所有入参之前， `&` 修饰的操作数就会发生变化（详细见关于 & 的解释部分）。

回到第3、4行，操作数 `%N`，其中 N = 0,1,2,...，表示依次出现的输入、输出参数，本例中 `%0` 为 `"=a"(res)`， `%1` 为 `"m"(*lock)`， `%3` 为 `"r"(set)`。如果在汇编指令的操作数中使用寄存器，需要用两个`%`，如 `movl %1, %%eax`。

还有一种数字限制符，如： `asm ("incl %0" :"=a"(var): "0"(var));`, `"0"(var)`表示 `var` 将与第0个操作数使用相同的寄存器，这样输入输出使用了相同的寄存器 eax。更多的常用限制符可以参考[这里](https://gcc.gnu.org/onlinedocs/gcc/Modifiers.html#Modifiers)。

第7行， `cc` 表示汇编代码将改变条件寄存器，`memory` 表示有内存被修改，我们需要将指令改变的寄存器放到 clobbered args 列表中，但不需要将输入、输出用到的寄存器放入其中。如果之前的汇编指令修改了 eax，而输入输出中没使用 eax， 则在 clobbered args 列表中加上 `"a"`。

第1行中的 `volatile` 表示每行汇编代码必须按给的次序执行。如果没有 `volatile`，编译器可能会对汇编代码做一些优化。对于常见的没有副作用的计算操作，不需要使用 `volatile`。

到这里，读懂 CAS 嵌入的汇编已经不成问题了。

# 关于 & 的解释
这是一个较常见用于输出的限定符，它告诉gcc输出操作数使用的寄存器不可再让输入操作数使用。对于 `"g"`，`"r"` 等限定符，为了有效利用为数不多的几个通用寄存器，gcc一般会让输入操作数和输出操作数选用同一个寄存器。但如果代码没编好，会引起 一些意想不到的错误。例如：
```c
asm("call fun;mov ebx,%1":"=a"(foo):"r"(bar));
```
gcc 编译的结果是 `foo` 和 `bar` 同时使用 eax 寄存器：
```c
       movl bar,eax
#APP
       call fun
       movl ebx,eax
#NO_APP
       movl eax,foo
```
本来这段代码的意图是将 `fun()` 函数的返回值放入 `foo` 变量，但半路杀出个程咬金，用 ebx 的值冲掉了返回值，所以这是一段错误的代码，解决的方法是输出操作数加上一个 `"&"` 限定符：
```c
asm("call fun;mov ebx,%1":"=&a"(foo):"r"(bar));
```
这样 gcc 就会让输入操作数另寻高就，不再使用 eax 寄存器了。

## 其他例子
### 两个数的加法
```c
int main(void) {
  int foo = 10, bar = 15;
  __asm__ __volatile__("addl  %%ebx,%%eax"
                       :"=a"(foo)
                       :"a"(foo), "b"(bar));
  printf("foo+bar=%d\n", foo);
  return 0;
}  
```

### 读取时间标签计数器
```c
static __inline__ unsigned long long rdtsc(void) {
  unsigned hi, lo;
  __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
  return ((unsigned long long)lo) | (((unsigned long long)hi)<<32);
}
```

### string copy
```c
static inline char* strcpy(char* dest, const char* src) {
  int d0, d1, d2;
  __asm__ __volatile__("1:\tlodsb\n\t"
                       "stosb\n\t"
                       "testb %%al,%%al\n\t"
                       "jne 1b"
                       : "=&S"(d0), "=&D"(d1), "=&a"(d2)
                       : "0"(src), "1"(dest)
                       : "memory");
  return dest;
}
```

## 参考资料
- [gcc 手册](https://gcc.gnu.org/onlinedocs/gcc/Using-Assembly-Language-with-C.html#Using-Assembly-Language-with-C)
- [gcc 嵌入汇编](http://www.cnblogs.com/whutzhou/articles/2638498.html)
- [gcc中的内嵌汇编语言](http://blog.csdn.net/zqy2000zqy/article/details/1137928)
