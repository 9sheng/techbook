# 一次 C++ vector 的误用

最近在项目中用到了很多这样的结构：有很多记录放在一个 vector 中，然后对这些记录建立了一些索引放在 map 中，大概结构如下：
```cpp
std::vector<Record> records;
std::map<Key, Record*> index;
```

构建数据的时候，大概流程如下：
```cpp
Record record;
while (getRecord(&record)) {
  records.push_back(record);
  Key key = makeKey(record);
  index[key] = &record;
}
```
错了，最后一句应该取 vector 中最后一个元素的地址，而不是变量 record 的地址。修改程序如下：
```cpp
Record record;
while (getRecord(&record)) {
  records.push_back(record);
  Key key = makeKey(record);
  index[key] = &(*records.rbegin());
}
```
结果运行的时候还是出错了。诡异的是，构建完索引后，打印索引里的 record 指针地址，竟然和原始的 vector 地址不一样，如果在循环中打印各个记录的地址，已经变了。

原因呢也很简单，但需要对 vector 的内部实现稍微有点了解—— vector 是如何分配内存的，当 vector push_back 新元素，但内部空间不够使用时， vector 会 realloc 新内存，然后将原有的元素拷贝过去，内存分配以 2 的次幂分配，第一次是 2^0 元素，第二次为 2^1 个，第三次为 2^2，这个可以通过调用 `std::vector::capacity()` 来验证。知道这些，有两个办法可以修复上述 bug。

1) 根据 records 最大数量，预先给 vector reserve 一段内存，确保 vector 不会重新分配内存。
```cpp
records.reserve(MAX_RECORD_NUM);
Record record;
while (getRecord(&record)) {
  records.push_back(record);
  Key key = makeKey(record);
  index[key] = &(*records.rbegin());
}
``` 
2) 构建完 vector 之后，再构建索引，注意：如果之后 vector 还会插入新纪录，index 还会失效，幸运的是，我们的程序构建完 vector 后就不会新增加元素了。
```cpp
Record record;
while (getRecord(&record)) {
  records.push_back(record);
}

for (auto iter = records.begin(); iter != records.end(); ++iter) {
  Key key = makeKey(*iter);
  index[key] = &(*iter);
}
```
---

**附录**

与 vector 的 size 相关的函数：

- `size()` 返回当前 vector 中的元素个数
- `capacity()` 放回当前 vector 内存空间可以元素数量
- `reserve(size_type n)` 分配至少可以存放 n 元素的空间
- `resize(size_type n, value_type val = value_type())` 将当前 vector 的元素数置为 n， 多删少补
- `shrink_to_fit()` **C++11 新增** 将 vector 占用的内存数 降低到和 size 数一致
