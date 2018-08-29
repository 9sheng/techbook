# Tuxedo性能调优之使用gprof

一个 tuxedo 应用系统的整体性能往往是由很多方面决定的，操作系统、网络、数据库、以及应用系统的设计，程序的编写水平都会影响该 tuxedo 应用系统的性能。当性能不好时,主要表现在对客户段的请求响应很慢。这时，如果用 tmadmin 中的 pq 命令察看，会发现有较多的请求在排队。

如何确认应用程序的瓶颈是性能调优的关键，也是难点。对于一个程序，如果可以知道每个函数的调用次数，调用时间，无疑会指引系统调优的方向。本文将介绍如何使用gprof查看tuxedo服务进程的函数调用情况，包括调用次数、调用时间、函数调用关系图等等。

gprof 是 GNU profiler 工具。基本用法如下：
1. 使用 `-pg` 选项编译和链接你的应用程序。
2. 执行你的应用程序，使之运行完成后生成供 gprof 分析的数据文件（默认是gmon.out）。
3. 使用 gprof 程序分析你的应用程序生成的数据，例如：`gporf a.out gmon.out`。

关于 gprof 的详细用法可以 google，有很多信息，这里不再赘述。

对于一个 tuxedo 程序，一般会编写很多 .cpp 文件，生成相应的 .o 文件，最后使用 buildserver 命令生成可执行文件。你会想在编译 .cpp 文件产生 .o 文件时，为编译器(系统为 linux 环境，编译器为 gcc)提供 -pg 选项，再使用 buildserver，但在 tmshutdown 服务进程之后，并没有发现 gmon.out 文件产生。为什么？

原来 gprof 只能在程序正常结束退出之后才能生成程序测评报告，原因是 gprof 通过在 atexit() 里注册一个函数来产生结果信息，任何非正常退出都不会执行 atexit() 的动作，所以不会产生 gmon.out 文件。如果你的程序是一个不会退出的服务程序，那就只有修改代码来达到目的。如果不想改变程序的运行方式，可以添加一个信号处理函数解决问题（这样对代码修改最少），例如：

```cpp
#include <unistd.h>
#include <signal.h>

static void catch_term(int sig_no) {
   exit(0);
}
  
int main() {
   signal(SIGTERM, catch_term);
   // 以下是原来的代码
}
```
当使用 `kill -TERM pid` 后，程序退出，生成 gmon.out 文件。

问题又来了，在 tuxedo 程序中，你只编写了应用服务的代码，并没有编写main函数，也就是说，buildserver 命令在编译时对你的代码做了一些手脚，查看 buildserver 帮助文档，可以看到使用 `-v` 选项可以详细显示 buildserver 的编译过程，使用这个选项可以容易看出 buildserver 实际上使用 gcc 来生成可执行文件，并添加了 tuxedo 相应的链接库，而且可以看到一个你没写过的 xxx.c，编译之后，这个 xxx.c 文件却消失了。

问题就在这，这个 xxx.c 文件中包含着 main 函数，buildserver 使用 `-k` 选项可以保留这个 xxx.c 文件而不被删除。在生成 xxx.c 后，按上面的方法注册一个 TERM 信号处理方法。此时不再用 buildserver 生成可执行文件，而是使用 `buildserver -v` 实际调用 gcc 的命令来生成可执行文件。

当你使用 `tmshutdown –s server –k TERM` (使用 TERM 信号结束程序)，还是没有产出 gmon.out，原因是在链接时 gcc 没有使用 -pg 选项；使用 `-pg` 选项重新编译链接程序，启动、结束服务程序后，终于看到久违的 gmon.out 文件了。

啊哈，现在可以查看运行的结果了。

参考资料：
- http://download.oracle.com/docs/cd/E13203_01/tuxedo/tux80/atmi/rfcmd8.htm
- http://forums.oracle.com/forums/thread.jspa?threadID=815390&tstart=2164
- http://apps.hi.baidu.com/share/detail/2292841
