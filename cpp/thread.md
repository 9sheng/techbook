# C++0x std::thread

一个简单的线程安全的队列实现
```cpp
#include <condition_variable>
#include <mutex>
#include <thread>

class ThreadSafeQueue {
 public:
  ThreadSafeQueue() {}

  void push(int data) {
    // 操作 data_queue_ 前需要加锁，执行完 notify_one 后需要释放锁，
    // 因为 data_cond_.wait 函数返回之前需要重新加锁
    std::lock_guard<std::mutex> lk(mut_);
    data_queue_.push(data);
    data_cond_.notify_one();
  }

  void wait_and_pop(int* value) {
    // 进入 wait 后，首先解锁，将本线程挂到条件变量等待列表上，
    // 解锁之后，push 才有可能获取到锁，向 queue 里写入数据
    // 在 wait 返回之前需要重新加锁，注意如果有多个线程等待
    // 条件变量，也需要一个一个地获得锁，这样一次只会有一个
    // 线程能取数据
    // 注意：wait 函数有可能返回多次，有些返回并不是 push 中的
    // data_cond_.notify_one 唤醒的
    std::unique_lock<std::mutex> lk(mut_);
    data_cond_.wait(lk, [this]{return !data_queue_.empty();});
    ,*value = std::move(data_queue_.front());
    data_queue_.pop();
  }

  bool empty() const {
    std::lock_guard<std::mutex> lk(mut_);
    return data_queue_.empty();
  }

 private:
  mutable std::mutex mut_;
  std::queue<int> data_queue_;
  std::condition_variable data_cond_;
};
```
