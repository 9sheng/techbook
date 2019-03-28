可靠（reliable）、可扩展（saclable）、可维护（maintainable）系统背后的深刻思想

------
# 第一章
- 服务的两个指标
  - service level objectives (SLOs)
  - service level agreements (SLAs)
- 可靠性
  - 意味着系统在故障发生的时候仍能正常运行
- 可维护性
  - Operability: Making Life Easy for Operations
  - Simplicity: Managing Complexity
  - Evolvability: Making Change Easy
- 可扩展性
  - 负载上升的时候，系统仍有办法保持较好的性能
- 好的抽象能降低系统的复杂性，使得系统更容易改造，以适用新的状况

# 第二章
- schema-on-read： 数据结构是隐式的，只有数据在读取之后才能解释
- schema-on-write：数据结构是显式的，如关系数据库
- NoSQL 数据库有以下两种类型
  - 文档形 Document databases，自包含的文档，文档之间很少有关系
  - 图形  Graph databases：关系随意设置

# 第三章
- log-structured 将数据库拆成变长的segment，通常有几M，并且顺序第写这些segment
- B-tree 将数据库拆成固定大小的blocks或pages，通常4KB，一次读写一个page，一个4层的4KB pages的 500 叉树，可以保持 256TB的数据
- 一般认为 LSM-trees 写快，B-trees 读快
- Bloom filter 是一个基于内存的数据结构，用来近似一个集合里的内容，他能告诉你一个key在集合里是否不存在，用来节省比必要的磁盘IO

# 第四章
常用的文本格式：JSON XML CSV；二进制格式：Thrift, Protocol Buffers, and Avro
web 服务有两种流行的方法： REST、SOAP。
- REST emphasizes simple data formats, using URLs for identifying resources and using HTTP features for cache control, authentication, and content type negotiation
- SOAP is an XML-based protocol for making network API requests

Finagle 和 Rest 使用 futures(promises)  来封装可能出错的异步调用。
异步的消息传输一般有两种：使用 messge brokers 或 actors。Actor 模型：每个 actor 实体（客户端）保存一些自己的状态，并且通过发送、接收异步消息和其他 actor 通讯

# 第五章
三种流行的复制模式
- Single-leader replication：客户端将所有的写请求发送给leader，leader将数据变化事件流发送给follower。读请求可以在任意节点上执行，但从follower上可能会读到过期数据
  - semi-synchronous：半同步，至少有个一个follower 和 leader 的数据一致
  - Replication Lag 的问题：eventual consistency，最终一致性
  - 脑裂
- Multi-leader replication：客户端发送写请求到能接受写请求的某的一个leader，leader将数据变化事件流发送给follower
  - 冲突解决
- Leaderless replication：客户端将写请求发送给几个节点，从几个节点中同时读数据，并判断修正有过期数据的节点
  - quorum read/write
  - sloppy quorum：读写仍有r/w个回复，但里面可能包括没有包含相应数据的节点
 
关于一致性
- 强一致性？？？
- Read-after-write consistency：用户应该总能看到自己之前提交过的数据
- Monotonic reads：用户看到某个时间点的数据后，他们不能读取到该时间点之前的数据
- Consistent prefix reads：用户应该看到的数据应该符合因果关系，先看到问题后看到回答

复制的方法
- statement-based replication：直接发SQL给从库
- write-ahead log（WAL） shipping：被 PostgreSQL 和 Oracle 使用
- Logical（row-based）log replication：Mysql binlog
- Trigger-based replication：Oracle GoldenGate

写冲突的解决
- on write：写数据时候发现冲突，调用冲突解决方法，通常冲突不会告诉用户，后台默默解决
- on read：检测到冲突后，所有的写冲突都被保存下来，当数据被读取时，应用通常告诉用户或自动地解决冲突，然后将结果写回数据库

常用冲突解决方法
- 每个 write 给一个唯一的ID（如时间戳，长随机数，UUID，kv 的hash值），选一个最大的ID写入，丢弃其他写。如果使用的是时间戳，即为last write wins (LWW)，该方法流行，但很危险
- 给每一个副本一个唯一的ID，有 higher- numbered 副本代替低lower- numbered副本，该方法也会丢数据
- 写入合并之后的数据，如按字母排序，并连接他们
- 用特殊的结构记录所有的冲突信息，后面再解决冲突

**分布式系统的基本问题**
- 节点宕机
- 不可靠的网络
- 副本间的权衡
  - 一致性
  - 持久性
  - 可用性
  - 延迟

# 第六章
partition 也叫 shard，目标是将数据和查询平均地分不到多台机器上，避免热点，主要有两种方法：
- key range partitioning：key是有序的，一个partition的key在一个区间范围内
- hash partitioning：一个 partition有一个范围的hash key，数据无序，但数据更平均
  - 一致性 hash，最初用来解决系统CDN缓存问题
  - 如果一个 key 使用非常频繁，可以再key前或后加一个随机数

二级索引 secondary index通常不是唯一确定一条记录，还是用来查找包含某个值的所有记录，通常会通过异步的方式更新一个全局的二级索引
- Document-partitioned indexes（local indexes）：二级索引存在partition本地，写快，读取时需要获取所有partition数据
- Term-partitioned indexes（global indexes）：一个分区的索引可能需要访问其他分区的数据，写慢，读快（只需要从一个分区读）

# 第七章
- ACID：Atomicity, Consistency, Isolation, Durablity
- BASE：Basically Available, Soft state, Eventual consistency
- Read Committed：最基本的隔离要求 ，无脏读写，只读到提交的数据，只覆盖写提交的数据。一般数据库采用行锁阻止脏写
- Snapshot Isolation（也叫 Repeatable Read）：关键原则是读不能阻塞写，写不能阻塞读，一般使用multi-version concurrency control(MVCC)实现，更新操作被拆为delete 和create。oracle里的实现叫 serializable，pg和mysql里叫 repeatable read
- Serializable Isolation（可串行化隔离）一般被认为是最强的隔离级别，他保证并行执行的时候，意味着数据库保证事务运行的效果和串行运行的一样（一次一个，没有并行），通常有三个方法实现
  - 字面上顺序执行事务：悲观至极锁，在一个CPU上，吞吐量小，VoltDB/H-Store、Redis、Datomic
 - Two-phase Locking(2PL)：悲观锁，对锁进行分类，分出共享锁（读锁）和排它锁（写锁），标准方式，性能不好，Mysql(InnoDB)，SQL Server shared-mode exclusive-mode
 - Seriazable Snapshot Isolation SSI，乐观锁，非常新的算法，允许事务无阻塞地执行，当想提交事务时，如果执行不是可串行化的则终止。和2PL相比，SSI的优点是一个事务不必因另一个事务阻塞；和并行处理相比，SSI不受限于一个CPUcore，FoundationDB通过检测多台机器上的冲突，从而获取了非常大的吞吐量

- Read skew (nonrepeatable reads)：客户在不同的时间看到不同部分的数据。使用Snapshot Isolation能避免这个问题，通常使用MVCC实现
- Write skew：事务读数据、处理、然后写回数据库，但在写库时，写入的数据不符合数据约束了，只有Serializable isolation能避免这个
- Phantom reads：事务读取符合某些搜索条件的对象，另一个客户写入了影响搜索结果的数据。Snapshot isolation 避免了这个，但是对于write skew 下的phantoms需要特殊处理，如index-range locks.

# 第八章
网络拥塞、排队、延迟总会发生
使用公网上的NTP服务，最好的延迟时间精确度是10万之一秒  
Java GC通常会停止整个线程
大多数拜占庭算法要求2/3的节点存活
通常UDP TCP的校验能检查出错误来，但有时也不行

# 第九章
evnentual consistency：意味着如果停止写数据库，一段时间之后，所有的读请求都返回同样的结果
分布式一致性主要是在有延迟、故障情况下协调多个副本的状态问题
This is the idea behind linearizability(also known as atomic consistency, strong consistency, immediate consistency, or external consistency). 
Serializability：可序列化，保证事务的执行像按某种顺序一个一个执行一样
Linearizability：是一个最近的关于读写一个寄存器的保证，他没有把一组操作当做事务处理，避免不了 write skew，本质上意味着只有一份数据，其上的所有的操作都是原子的
serial execution和2PL 都是 Linearizability，SSI 不是 Linearizability 的
CAP更好的理解，当网络故障发生的时候，只能选择 linearizability 或者 total availability；或者说，当发生Partitioned时候，只能选择 Consistent 或者Available 
放弃 linearizability 的原因是 performanc，而不是fault tolerance
 a total order and a partial order：
- 在 Linearizability 系统中，是total order的，所有的操作都有序
- Causality，是partial order的，某些操作是可以并行的
可以证明 linearizable compare-and-set register 和 total order broadcast 和 consensus 是等价的
补偿性事务
2PC：在一个分布式数据库中提供了 atomic commit；2PL 提供了 Serialization Isolation；2PC 有故障时只能等待协调者恢复
(Termination is a liveness property, whereas the other three are safety properties
The best-known fault-tolerant consensus algorithms are Viewstamped Replication (VSR)  Paxos， Raft and Zab

# 第十章
shuffle 洗牌
sort-merge join

# 第十一章
如果发送者的发送速度大于消费者的消费速度，系统可以丢掉消息或者在队列里缓存消息或者使用backpressure（流量控制），Unix pipes and TCP use backpressure
event sourcing 和 change data capture 最大的缺点是他们的消费者通常都是异步的

# 第十二章
在分布式事务协议的本质上，我认为log-based derived data 是最有前途的集成系统的方法
通常，建立一个完全有序的日志，需要所有的事件都经由一个leader来处理，如果吞吐量超过一台机器的处理量，需要使用多台机器分区处理
当数据跨过各种技术边界时，我认为基于 dempotent writes 的 asynchronous event log是一个更具鲁棒性和实用性的方法
系统从 request/ response 交互到 publish/subscribe dataflow
我们假设数据写入磁盘在fsync后不会丢失，内存中的数据不会损坏，CPU总会返回正确的执行结果
