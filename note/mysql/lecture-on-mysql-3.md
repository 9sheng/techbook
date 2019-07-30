# 21 | 为什么我只改一行的语句，锁这么多?
- 我总结的加锁规则里面，包含了两个“原则”、两个“优化”和一个“bug”。
  - 原则1：加锁的基本单位是next-keylock。希望你还记得，next-keylock是前开后闭区间。
  - 原则2：查找过程中访问到的对象才会加锁。
  - 优化1：索引上的等值查询，给唯一索引加锁的时候，next-keylock退化为行锁。
  - 优化2：索引上的等值查询，向右遍历时且最后一个值不满足等值条件的时候，next-key lock退化为间隙锁。
  - 一个bug：唯一索引上的范围查询会访问到不满足条件的第一个值为止。
- lock in share mode只锁覆盖索引，但是如果是for update就不一样 了。 执行 for update时，系统会认为你接下来要更新数据，因此会顺便给主键索引上满足条件的行加上行锁。锁是加在索引上的;同时，它给我们的指导是，如果你要用lock in share mode 来给行加读锁避免数据被更新的话，就必须得绕过覆盖索引的优化，在查询字段中加入索引中不 存在的字段。
- next-key lock实际上是由间隙锁加行锁实现的。如果切换到读提交隔离级别(read-committed)的话，就好理解了，过程中去掉间隙锁的部分，也就是只剩下行锁的部分。其实读提交隔离级别在外键场景下还是有间隙锁，相对比较复杂。另外，在读提交隔离级别下还有一个优化，即:语句执行过程中加上的行锁，在语句执行完成后，就要把“不满足条件的行”上的行锁直接释放了，不需要等到事务提交。也就是说，读提交隔离级别下，锁的范围更小，锁的时间更短，这也是不少业务都默认使用读提交隔离级别的原因。
- 在删除数据的时候尽量加limit。这样不仅可以控制删除 数据的条数，让操作更安全，还可以减小加锁的范围。
- **mysql 扫描索引时候，需要扫到哪一行，就要给哪一行加上  next-keylock**，然后按上面的原则优化

# 22 | MySQL有哪些“饮鸩止渴”提高性能的方法?
- 短连接模型存在一个风险，就是一旦数据库处理得慢一些，连接数就会暴涨。 max_connections参数，用来控制一个MySQL实例同时存在的连接数的上限，超过这个值，系统就会拒绝接下来的连接请求，并报错提示“Too many connections”。
- 在MySQL中，会引发性能问题的慢查询，大体有以下三种可能: 
  - 索引没有设计好
    - alter table 增加索引
  - SQL语句没写好
    - 可以用 sql 重写： insert into query_rewrite.rewrite_rules(pattern, replacement, pattern_database) values(); call query_rewrite.flush_rewrite_rules();
  - MySQL选错了索引
    - force index

# 23 | MySQL是怎么保证数据不丢的?
### binlog的写入逻辑
- 事务执行过程中，先把日志写到binlog cache，事务提交的时候，再把binlog cache写到binlog文件中。系统给binlog cache分配了一片内存，每个线程一个，参数binlog_cache_size 用于控制单个线程内binlog cache所占内存的大小。如果超过了这个参数规定的大小，就要暂存到磁盘。事务提交的时候，执行器把binlog cache里的完整事务写入到binlog中，并清空binlog cache。
- 图中的write，指的就是指把日志写入到文件系统的page cache。图中的fsync，才是将数据持久化到磁盘的操作。一般情况下，我们认为fsync才占磁盘的 IOPS。
  - sync_binlog=0的时候，表示每次提交事务都只write，不fsync;
  - sync_binlog=1的时候，表示每次提交事务都会执行fsync;
  - sync_binlog=N(N>1)的时候，表示每次提交事务都write，但累积N个事务后才fsync。
  - 在出现IO瓶颈的场景里，将sync_binlog设置成一个比较大的值，可以提升性能。在实际 的业务场景中，考虑到丢失日志量的可控性，一般不建议将这个参数设成0，比较常见的是将其 设置为100~1000中的某个数值。将sync_binlog设置为N，对应的风险是:如果主机发生异常重启，会丢失最近N个事务的 binlog日志。
### redo log的写入机制
- 事务在执行过程中，生成的redo log是要先写到redo log buffer的
- redo log可能存在的三种状态
  - 存在redologbuffer中，物理上是在MySQL进程内存中
  - 写到磁盘(write)，但是没有持久化(fsync)，物理上是在文件系统的pagecache里面
  - 持久化到磁盘，对应的是harddisk

为了控制redo log的写入策略，InnoDB提供了innodb_flush_log_at_trx_commit参数，它有三种 可能取值:
1. 设置为0的时候，表示每次事务提交时都只是把redolog留在redologbuffer中;
2. 设置为1的时候，表示每次事务提交时都将redolog直接持久化到磁盘;
3. 设置为2的时候，表示每次事务提交时都只是把redolog写到pagecache。

InnoDB有一个后台线程，每隔1秒，就会把redo log buffer中的日志，调用write写到文件系统的 page cache，然后调用fsync持久化到磁盘。事务执行中间过程的redo log也是直接写在redo log buffer中的，这些redo log也会被后台 线程一起持久化到磁盘。也就是说，一个没有提交的事务的redo log，也是可能已经持久化到磁 盘的。

除了后台线程每秒一次的轮询操作外，还有两种场景会让一个没有提交的事务的redo log写入到磁盘中。
1. 一种是，redo log buffer占用的空间即将达到 innodb_log_buffer_size一半的时候， 后台线程会主动写盘。注意，由于这个事务并没有提交，所以这个写盘动作只是write，而 没有调用fsync，也就是只留在了文件系统的page cache。
2. 另一种是，并行的事务提交的时候，顺带将这个事务的redo log buffer持久化到磁 盘。假设一个事务A执行到一半，已经写了一些redo log到buffer中，这时候有另外一个线程 的事务B提交，如果innodb_flush_log_at_trx_commit设置的是1，那么按照这个参数的逻 辑，事务B要把redo log buffer里的日志全部持久化到磁盘。这时候，就会带上事务A在redo log buffer里的日志一起持久化到磁盘。
- 如果把innodb_flush_log_at_trx_commit设置成1，那么redo log在prepare阶段就要持久化一次， 因为有一个崩溃恢复逻辑是要依赖于prepare 的redo log，再加上binlog来恢复的。
- 通常我们说MySQL的“双1”配置，指的就是sync_binlog和innodb_flush_log_at_trx_commit都设 置成 1。也就是说，一个事务完整提交前，需要等待两次刷盘，一次是redo log(prepare 阶 段)，一次是binlog。

### 组提交(group commit)机制
redo log 和 binlog 都有组提交机制
日志逻辑序列号(log sequence number，LSN)的概念。LSN是单调 递增的，用来对应redo log的一个个写入点。每次写入长度为length的redo log， LSN的值就会加 上length。
一次组提交里面，组员越多，节约磁盘IOPS的效果越好。第一个事务写完redo log buffer以后，接下来这个fsync越晚调用，组员可能
越多，节约IOPS的效果就越好。

如果你想提升binlog组提交的效果，可以通过设置 binlog_group_commit_sync_delay和 binlog_group_commit_sync_no_delay_count来实现。
1. binlog_group_commit_sync_delay参数，表示延迟多少微秒后才调用fsync;
1. binlog_group_commit_sync_no_delay_count参数，表示累积多少次以后才调用fsync。 这两个条件是或的关系，也就是说只要有一个满足条件就会调用fsync。

如果你的MySQL现在出现了性能瓶颈，而且瓶颈在IO 上，可以通过哪些方法来提升性能呢?针对这个问题，可以考虑以下三种方法:
1. 设置 binlog_group_commit_sync_delay（延迟多少微秒后才调用fsync）和 binlog_group_commit_sync_no_delay_count参数（等待这么长时间，表示累积多少次以后才调用fsync），减少binlog的写盘次数。这个方法是基于“额外的故意等待”来实现的，因此可能会增加语句的响应时间，但没有丢失数据的风险。
1. 将sync_binlog设置为大于1的值(比较常见是100~1000)。这样做的风险是，主机掉电时 会丢binlog日志。
1. 将innodb_flush_log_at_trx_commit设置为2。这样做的风险是，主机掉电的时候会丢数据。
不建议你把innodb_flush_log_at_trx_commit 设置成0。因为把这个参数设置成0，表示redo log只保存在内存中，这样的话MySQL本身异常重启也会丢数据，风险太大。而redo log写到文 件系统的page cache的速度也是很快的，所以将这个参数设置成2跟设置成0其实性能差不多， 但这样做MySQL异常重启时就不会丢数据了，相比之下风险会更小。

# 25 | MySQL是怎么保证高可用的?
- 主备延迟的来源
  - 首先，有些部署条件下，备库所在机器的性能要比主库所在的机器性能差。
  - 第二种常见的可能了，即备库的压力大
  - 第三种可能了，即大事务：因为主库上必须等事务执行完成才会写入binlog，再传给备库，另一种典型的大事务场景，就是大表DDL。
- 在实际的应用中，我更建议使用可靠性优先的策略。毕竟保证数据准确，应该是数据库服务的底 线。在这个基础上，通过减少主备延迟，提升系统的可用性。
- 一般现在的数据库运维系统都有备库延迟监控，其实就是在备库上执行 show slave status，采集seconds_behind_master的值。

# 26 | 备库为什么会延迟好几个小时?

- work线程的个数，就是由参数 slave_parallel_workers决定的。根据我的经验，把这个值设置为8~16之间最好(32核物理机的 情况)，毕竟备库还有可能要提供读查询，不能把CPU都吃光了。
- 多线程复制呢?这是因为单线程复制的能力全面低于多线程复制，对于更新压力较大 的主库，备库是可能一直追不上主库的。从现象上看就是，备库上seconds_behind_master的值 越来越大。
- 官方MySQL5.6版本，支持了并行复制，只是支持的粒度是按库并行。理解了上面介绍的按表分发策略和按行分发策略，你就理解了，用于决定分发策略的hash表里，key就是数据库名。
- MariaDB是这么做的:
  1. 在一组里面一起提交的事务，有一个相同的commit_id，下一组就是commit_id+1; 
  2. commit_id直接写到binlog里面;
  3. 传到备库应用的时候，相同commit_id的事务分发到多个worker执行;
  4. 这一组全部执行完成后，coordinator再去取下一批。
- MySQL 5.7的并行复制策略
  1. 配置为DATABASE，表示使用MySQL5.6版本的按库并行策略;
  2. 配置为 LOGICAL_CLOCK，表示的就是类似MariaDB的策略。不过，MySQL 5.7这个策 略，针对并行度做了优化。这个优化的思路也很有趣儿。
- MySQL 5.7.22的并行复制策略
- 基于WRITESET的并行复制。 相应地，新增了一个参数binlog-transaction-dependency-tracking，用来控制是否启用这个新策略。这个参数的可选值有以下三种。
  1. COMMIT_ORDER，表示的就是前面介绍的，根据同时进入prepare和commit来判断是否可 以并行的策略。
  2. WRITESET，表示的是对于事务涉及更新的每一行，计算出这一行的hash值，组成集合 writeset。如果两个事务没有操作相同的行，也就是说它们的writeset没有交集，就可以并 行。
  3. WRITESET_SESSION，是在WRITESET的基础上多了一个约束，即在主库上同一个线程 先后执行的两个事务，在备库执行的时候，要保证相同的先后顺序。
