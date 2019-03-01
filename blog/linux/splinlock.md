# Linux自旋锁spinlock的使用

在 Linux 中提供了一些机制用来避免竞争条件，最简单的一个种就是自旋锁，例如：当一个临界区的数据在多个函数之间被调用时，为了保护数据不被破坏，可以采用 spinlock 来保护临界区的数据。

## 定义和初始化spinlock
在 linux 中定义 spinlock 的方法很简单，与普通的结构体定义方式是一样的。其代码如下：

```c
spinlock_t spinlock = SPIN_LOCK_UNLOCKED;
```
一个自旋锁必须初始化才能被使用，可以通过在编译阶段通过宏定义来实现，比如上面的 `SPIN_LOCK_UNLOCKED`，这个表示一个没有锁定的自旋锁。同时在运行阶段可以使用 `spin_lock_init()` 函数动态地初始化一个自旋锁，其函数原型如下：

```c
spinlock_t spin_lock_init(spinlock_t lock);
```

## 锁定自旋锁
进入临界区之前，需要使用 spin_lock 宏定义来锁定自旋锁，spin_lock 宏定义的代码如下：

```c
#define spin_lock(lock) _spin_lock(lock)
```
这个宏用来获得 lock 的自旋锁，如果能够立即获得自旋锁，则宏立刻返回，否则，这个宏一直等待下去，直到被其它线程释放为止。

## 释放自旋锁
退出临界区之前，需要使用spin_unlock宏定义来释放自旋锁。spin_unlock宏定义的代码如下：

```c
#define spin_unlock(lock) _spin_unlock(lock)
```

这个宏用来释放 lock 的自旋锁，当调用该宏后，自旋锁立刻被释放。

## 使用自旋锁

在驱动程序中，有些设备只允许打开一次，那么就需要一个自旋锁保护表示设备打开或者关闭的状态的一个变量 status，此处的 status 为一个临界资源，如果不对 status 进行保护，当设备频繁的打开时，就有可能出现错误的 status 的状态，所以必须对 status 进行保护，其代码如下：

```c
int  OpenCloseStatus;
spinlock_t spinlock;

int xxxx_init(void) {
    ...
    spin_lock_init(&spinlock);
    ...
}

int xxxx_open(struct  inode *inode, struct file *filp) {
    ...
    spin_lock(&spinlock);
    if (OpenCloseStatus) {
        spin_unlock(&spinlock);
        return EBUSY;
    }
    status++;
    spin_unlock(&spinlock);
    ...
}

int xxxx_release(struct  inode *inode, struct file *filp) {
    ...
    spin_lock(&spinlock);
    status--;
    spin_unlock(&spinlock);
    ...
}
```

## 自旋锁使用注意事项

- 自旋锁一种忙等待，当条件不满足时，会一直不断的循环判断条件是否满足，如果满足就解锁，运行之后的代码。因此会对 linux 的系统的性能有些影响。所以在实际编程时，需要注意自旋锁不应该长时间的持有。它适合于短时间的的轻量级的加锁机制。

- 自旋锁不能递归使用，这是因为自旋锁，在设计之初就被设计成在不同进程或者函数之间同步。所以不能用于递归使用。
