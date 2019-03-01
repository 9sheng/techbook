# 如何证明fork用了COW？

写时复制(COW，Copy on Write) 是一个众所周知的概念，古老又伟大的 unix 利用了这一个特性，在当时，内存非常昂贵，cpu 计算资源极其昂贵，因此有必要用这种懒惰的方式来节省时间和空间。但怎么证明fork时内核真的用了这种技术呢？如果对linux内核代码很熟悉的话，当然可以直接阅读代码，找到蛛丝马迹。但如果像我等小白对linux内核代码不熟悉，又该改怎么办呢？

首先祭出我们的法宝 [stap](http://sourceware.org/systemtap/)，借助它，我们可以看看在 fork 之后，父进程和子进程对内存的读写时，到底发生了哪些系统调用。由于我们用到该工具的东西很简单，这里不再详细介绍。

下面看我们的测试程序，该程序很简单，进程首先大块大块地申请内存，然后 fork 出一个子进程1，子进程1对刚才申请的空间做只读操作；父进程继续 fork 出一个子进程2，子进程2对刚才的空间做读写操作。里面的 sleep 函数只是为了延时，便于有时间我们操作。程序如下：

```c
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<unistd.h>
#include<sys/types.h>
#include<sys/wait.h>

int main()
{
    int i = 0;
    char* ptr[1000];

    for (i = 0; i < 1000; i++)
    {
        ptr[i] = (char*) malloc(102400);
        memset(ptr[i], '0', 102400);
    }

    sleep(15);

    int ret = fork();

    if (ret < 0)
    {
        fprintf(stderr,"fork failed ,nothing to do now!\n");
        return -1;
    }
    else if (ret == 0)
    {
        sleep(10);
        fprintf(stderr, "I'm the 1st child(%d). I begin to read now\n", getpid());
        for (i = 0; i < 1000; i++)
            printf("%c", ptr[i][10240]);
        printf("\n");
        return 0;
    }
    else if (ret > 0)
    {
        int ret2 = fork();
        if (ret2 == 0)
        {
            sleep(10);
            fprintf(stderr, "I'm the 2nd child(%d). I begin to write now\n",  getpid());
            for (i = 0; i < 1000; i++)
                printf("%c", ptr[i][10240] = 'C');
            printf("\n");
        }
        else
        {
            waitpid(-1, NULL, 0);
            fprintf(stderr, "Child process exit, now check the value\n");
            for (i = 0; i < 1000; i++)
                printf("%c", ptr[i][10240]);
            printf("\n");
            return 0;
        }
    }
}
```

stap 的脚本更为简单，该脚本只是简单监控上述进程以及两个子进程在何时调用了内核函数 `copy_page` (或 `do_wp_page` )，为什么要监控这个函数，这里还是需要对内核代码有一定的了解，不过不了解也没多大关系，google 一下，胡乱看些介绍文章估计也会有大致了解（见参考资料）。然后脚本会在60s后自动退出。脚本如下：

```sh
#!/usr/bin/stap

probe kernel.function("copy_page") {
  if(pid() == target() || ppid() == target()) {
     printf("copy_page(@%d):pid(%d)\n", gettimeofday_us(), pid())
  }
}

probe timer.s(60) {
   exit();
}
```

运行脚本 `sudo stap copy-page.stap -x 6300`，运行结果如下：
- 父进程  pid = 6300，共有 **13** 次 copy_page 调用
- 子进程1 pid = 6308，共有 **3** 次 copy_page 调用
- 子进程2 pid = 6309，共有 **312** 次 copy_page 调用

细心的看官可能发现，示例代码中申请了内存之后，马上进行了 memset 操作，也就是对内存进行读写操作。如果没有这些操作，结果又是另外一个样子：父进程的 copy_page 调用次数基本没变，而子进程1 和子进程2的 copy_page 操作分别是1次和2次。

为什么变化这么大？内核发生了什么？看来内核对我们隐瞒了太多的东西，这个以后再验证了。猜测当 malloc 时，linux 只是分配了虚拟内存（地址），但没有真正分配内存，实际读写数据时才会真正触发缺页（pagefault），此时才会真正触发物理内存的分配，但这时候子进程只是分配新内存，而不需要复制主进程的内存。


### 参考资料

- http://blog.chinaunix.net/uid-24774106-id-3361500.html
- http://blog.csdn.net/vanbreaker/article/details/7955713
- http://proxy3.zju88.net/agent/thread.do?id=LinuxDev-48aa2848-065dd11ca3f0faee1115345308cfab11&page=0&bd=LinuxDev&bp=28&m=0
- http://blog.csdn.net/yunsongice/article/details/5637671
