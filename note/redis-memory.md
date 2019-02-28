#Redis内存管理和持久化 

支持的数据类型： string、list、set、hash、sorted set

## 数据结构
```c
typedef struct redisObject {
  unsigned type,     // 4字节，数据类型(String,List,Set,Hash,Sorted Set)
  unsigned encoding, // 4字节，编码方式
  unsigned lru,      // 24字节
  int refcount,      // 对象引用计数
  void *ptr,         // 数据具体存储的指向
} robj;
```

## 编码方式
- RAW：RedisObject的ptr指向名为sds的空间，包含Len和Free头部和buf的实际数据，Free采用了某种预分配（若Len<1M，则Free分配与Len大小一致的空间；若大于Len>=1M，则Free分配1M空间；SDS的长度为Len+Free+buf+1(额外的1字节用于保存空字符)）
- EMBSTR：与RedisObject在连续的一块内存空间，省去了多次内存分配；条件是字符串长度<=39
- INT：字符串的特殊编码方式，若存储的字符串是整数时，则ptr本身会等于该整数，省去了sds的空间开销；实际上Redis在启动时会默认创建10000个RedisObject，代表0-10000的整数
- ZipList(压缩列表)：除了一些标志性字段外用一块类似数组的连续空间来进行存储，缺点是读写时整个压缩列表都需要更改，一般能达到10倍的压缩比。Hash默认值为512，List默认是64
- Hash Table：默认初始大小为4，使用链地址法解决hash冲突；rehash策略：将原来表中的数据rehash并放入新表，之后替换；大量rehash可能会造成服务不可用，因此Redis使用渐进式rehash策略，分批进行

## 过期清理
Redis对于过期键有三种清除策略： 
- 被动删除：当读/写一个已经过期的key时，会触发惰性删除策略，直接删除掉这个过期key
  - 只有key被操作时(如GET)，REDIS才会被动检查该key是否过期，如果过期则删除之并且返回NIL
  - 这种删除策略对CPU是友好的，删除操作只有在不得不的情况下才会进行，不会对其他的expire key上浪费无谓的CPU时间
  - 但是这种策略对内存不友好，一个key已经过期，但是在它被操作之前不会被删除，仍然占据内存空间
- 主动删除：由于惰性删除策略无法保证冷数据被及时删掉，所以Redis会定期主动淘汰一批已过期的key
  - 系统空闲时做后台定时清理任务（时间限制为25%的CPU时间）；Redis后台清理任务默认100ms执行1次，25%限制是表示25ms用来执行key清理
  - 依次遍历所有db；
  - 从db中随机取得20个key，判断是否过期，若过期，则剔除；
  - 若有5个以上的key的过期，则重复步骤2，否则遍历下一个db
  - 清理过程中若达到了时间限制，则退出清理过程
- 当前已用内存超过maxmemory限定时，触发主动清理策略
  - volatile-lru：只对设置了过期时间的key进行LRU（默认值）
  - allkeys-lru：删除lru算法的key
  - volatile-random：随机删除即将过期key
  - allkeys-random：随机删除
  - volatile-ttl：删除即将过期的
  - noeviction：永不过期，返回错误

## 持久化
持久化对过期key的处理
- 持久化key之前，会检查是否过期，过期的key不进入RDB文件
- 从RDB文件恢复数据到内存数据库 数据载入数据库之前，会对key先进行过期检查，如果过期，不导入数据库（主库情况）
- 从内存数据库持久化数据到AOF文件，当key过期后，还没有被删除，此时进行执行持久化操作
- 当key过期后，在发生删除操作时，程序会向aof文件追加一条del命令
- aof重写时，会先判断key是否过期，已过期的key不会重写到aof文件

Redis支持四种持久化方式；如下： 
- 定时快照方式(snapshot)[RDB方式]
- 基于语句追加文件的方式(aof)
- 虚拟内存(vm)，已被放弃
- Diskstore方式，实验阶段
