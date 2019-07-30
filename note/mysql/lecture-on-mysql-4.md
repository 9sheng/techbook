# 27 | 主库出问题了，从库怎么办?
GTID的全称是Global Transaction Identifier，也就是全局事务ID，是一个事务在**提交**的时候生成的，是这个事务的唯一标识。
实例B上执行start slave命令，取binlog的逻辑是这样的：
1. 实例B指定主库A’，基于主备协议建立连接。
1. 实例B把set_b发给主库A’。
1. 实例A’算出set_a与set_b的差集，也就是所有存在于set_a，但是不存在于set_b的GITD的集合，判断A’本地是否包含了这个差集需要的所有binlog事务。
   - 如果不包含，表示A’已经把实例B需要的binlog给删掉了，直接返回错误；
   - 如果确认全部包含，A’从自己的binlog文件里面，找出第一个不在set_b的事务，发给B；
1. 之后就从这个事务开始，往后读文件，按顺序取binlog发给B去执行。

# 28 | 读写分离有哪些坑?
- 读写分离的方案
  - 客户端直连方案
  - 带proxy的架构，对客户端比较友好
- 解决主从延迟方案
  - 强制走主库方案；（其实这个方案是用得最多的。）
  - sleep方案； 
  - 判断主备无延迟方案；
  -  配合semi-sync方案；
  - 等主库位点方案
    - 在主库执行完插入之后，执行`show master status`，然后根据 file pos 去从库执行 `select master_pos_wait(file, pos[, timeout])；` 如果返回值 >=0，说明数据同步了。
  - 等GTID方案。
    - 你只需要将参数session_track_gtids设置为OWN_GTID，然后通过API接口mysql_session_track_get_first从返回包解析出GTID的值即可。
    - `select wait_for_executed_gtid_set(gtid_set, 1)；`
- semi-sync做了这样的设计:
  1. 事务提交的时候，主库把binlog发给从库；
  1. 从库收到binlog以后，发回给主库一个ack，表示收到了；
  1. 主库收到这个ack以后，才能给客户端返回“事务完成”的确认。
  > 但是，semi-sync+位点判断的方案，只对一主一备的场景是成立的。在一主多从场景中，主库只 要等到一个从库的ack，就开始给客户端返回确认。
- 有的方案看上去是做了妥协，有的方案看上去不那么靠谱儿，但都是有实际应用场景的，你需要根据业务需求选择。

# 29 | 如何判断一个数据库是不是出问题了?
- 查询判断：`select 1；` 不能检测因为并发查询限制带来的问题 MHA默认用了这个
  - 我们设置innodb_thread_concurrency参数的目的是，控制InnoDB的并发线程上限。也就是说，一旦并发线程数达到这个值，InnoDB在接收到新请求的时候，就会进入等待状态，直到有线程 退出。通常情况下，我们建议把innodb_thread_concurrency设置为64~128之间的值。这时，你 一定会有疑问，并发线程上限数设置为128够干啥，线上的并发连接数动不动就上千了。
  - 并发连接和并发查询，并不是同一个概念。你在show processlist的结果里，看到的几千个连 接，指的就是并发连接。而“当前正在执行”的语句，才是我们所说的并发查询。
- 查询判断：`select * from mysql.health_check；`，不能确认是否能更新，如磁盘慢，binlog不能写入等
- 更新判断：`update mysql.health_check set t_modified=now()；`，主从冲突，可能需要多行
  ` insert into mysql.health_check(id, t_modified) values (@@server_id, now()) on duplicate key update t_modified=now()；`
  更新语句，如果失败或者超时，就可以发起主备切换了，为什么还会有判定 慢的问题呢? 一个日志盘的IO利用率已经是100%的场景，但我们的update 成功了，得出系统正常的结论。
- mysql 内部统计，使用 performance_schema
  - 如果打开所有的performance_schema项，性能大概会下降10%左右

# 30 | 答疑文章(二):用动态的观点看加锁

# 31 | 误删数据后除了跑路， 还能怎么办？
- 我们提到如果是使用delete语句误删了数据行， 可以用Flashback工具通过闪回把数据恢复回来。Flashback恢复数据的原理， 是修改binlog的内容， 拿回原库重放。 而能够使用这个方案的前提是，需要确保binlog_format=row和 binlog_row_image=FULL。
- 恢复数据比较安全的做法，是恢复出一个备份，或者找一个从库作为临时库，在这个临时库上执行这些操作，然后再将确认过的临时库的数据，恢复回主库。
- delete全表是很慢的， 需要生成回滚日志、 写redo、 写binlog。 所以，从性能角度考虑，你应该优先考虑使用truncate table或者drop table命令。
- 延迟复制备库： 延迟复制的备库是一种特殊的备库， 通过 `CHANGE MASTER TO MASTER_DELAY = N`命令，可以指定这个备库持续保持跟主库有N秒的延迟。
- 预防误删库/表的方法
  - 只给业务开发同学DML权限，而不给truncate/drop权限。而如果业务开发人员有DDL需求的话，也可以通过开发管理系统得到支持。
  - DBA团队成员，日常也都规定只使用只读账号，必要的时候才使用有更新权限的账号。
  - 在删除数据表之前，必须先对表做改名操作。然后，观察一段时间，确保对业务无影响以后再删除这张表。
  - 改表名的时候，要求给表名加固定的后缀（比如加_to_be_deleted)，然后删除表的动作必须通过管理系统执行。并且管理系删除表的时候，只能删除固定后缀的表。
- rm 删除：一个有高可用机制的MySQL集群来说， 最不怕的就是rm删除数据了。只要不是恶意地把整个集群删除，而只是删掉了其中某一个节点的数据的话，HA系统就会开始工作，选出一个新的主库， 从而保证整个集群的正常工作。

# 32 | 为什么还有kill不掉的语句？
- 在MySQL中有两个kill命令：一个是kill query+线程id，表示终止这个线程中正在执行的语句；一个是kill connection +线程id，这里connection可缺省，表示断开这个线程的连接，当然如果这个线程有语句正在执行， 也是要先停止正在执行的语句的。
- 当用户执行kill query thread_id_B时， MySQL里处理kill命令的线程做了两件事：
  1. 把session B的运行状态改成THD::KILL_QUERY(将变量killed赋值为THD::KILL_QUERY)；
  2. 给session B的执行线程发一个信号。
- 当 session E执行kill connection 命令时， 是这么做的：
  1. 把12号线程状态设置为KILL_CONNECTION；
  2. 关掉12号线程的网络连接。 因为有这个操作， 所以你会看到， 这时候session C收到了断开连接的提示
      如果一个线程的状态是KILL_CONNECTION， 就把Command列显示成Killed 只有等到满足进入InnoDB的条件后， session C的查询语句继续执行， 然后才有可能判断到线程状态已经变成了KILL_QUERY或者KILL_CONNECTION， 再进入终止逻辑阶段。
- MySQL客户端发送请求后， 接收服务端返回结果的方式有两种：
  1. 一种是本地缓存， 也就是在本地开一片内存， 先把结果存起来。 如果你用API开发， 对应的就是mysql_store_result 方法。
  2. 另一种是不缓存， 读一个处理一个。 如果你用API开发， 对应的就是mysql_use_result方法。
- 除了加-A以外， 加–quick(或者简写为-q)参数， 也可以跳过这个阶段。 但是， 这个–quick是一个更容易引起误会的参数， 也是关于客户端常见的一个误解。为什么要给这个参数取名叫作quick呢？ 这是因为使用这个参数可以达到以下三点效果：
  - 就是前面提到的， 跳过表名自动补全功能。
  - mysql_store_result需要申请本地内存来缓存查询结果， 如果查询结果太大， 会耗费较多的本地内存， 可能会影响客户端本地机器的性能；
  - 是不会把执行命令记录到本地的命令历史文件

# 33 | 我查这么多数据， 会不会把数据库内存打爆？
- 对于正常的线上业务来说， 如果一个查询的返回结果不会很多的话， 我都建议你使用mysql_store_result这个接口， 直接把查询结果保存到本地内存。
- 仅当一个线程处于“等待客户端接收结果”的状态， 才会显示"Sending to client"； 而如果显示成“Sending data”， 它的意思只是“正在执行”
- 可以在 `show engine innodb status` 结果中， 查看一个系统当前的BP命中率。 一般情况下， 一个稳定服务的线上系统， 要保证响应时间符合要求的话， 内存命中率要在99%以上。
- InnoDB Buffer Pool的大小是由参数 `innodb_buffer_pool_size`确定的， 一般建议设置成可用物理内存的60%~80%  InnoDB内存管理用的是最近最少使用 (Least RecentlyUsed, LRU)算法， 这个算法的核心就是淘汰最久未使用的数据。

在InnoDB实现上， 按照5:3的比例把整个LRU链表分成了young区域和old区域。 图中LRU_old指向的就是old区域的第一个位置， 是整个链表的5/8处。 也就是说， 靠近链表头部的5/8是young区域， 靠近链表尾部的3/8是old区域。
1. 要访问数据页P3， 由于P3在young区域， 因此和优化前的LRU算法一样， 将其移到链表头部， 变成状态2。
2. 之后要访问一个新的不存在于当前链表的数据页， 这时候依然是淘汰掉数据页Pm， 但是新插入的数据页Px， 是放在LRU_old处。
3. 处于old区域的数据页， 每次被访问的时候都要做下面这个判断：
   - 若这个数据页在LRU链表中存在的时间超过了1秒， 就把它移动到链表头部；
   - 如果这个数据页在LRU链表中存在的时间短于1秒， 位置保持不变。 1秒这个时间， 是由参数innodb_old_blocks_time控制的。 其默认值是1000， 单位毫秒。


# 34 | 到底可不可以使用join?
- 使用join语句，性能比强行拆成多个单表执行SQL语句的性能要好；
- 如果使用join语句的话，需要让小表做驱动表。（可以使用被驱动表的索引）
- 能不能使用join语句?
  - 如果可以使用IndexNested-LoopJoin算法，也就是说可以用上被驱动表上的索引，其实是没问题的；
  - 如果使用BlockNested-LoopJoin算法，扫描行数就会过多。尤其是在大表上的join操作，这 样可能要扫描被驱动表很多次，会占用大量的系统资源。所以这种join尽量不要用。所以你在判断要不要使用join语句时，就是看explain结果里面，Extra字段里面有没有出现“Block Nested Loop”字样。
- 如果要使用join，应该选择大表做驱动表还是选择小表做驱动表? 
  - 如果是IndexNested-LoopJoin算法，应该选择小表做驱动表；
  - 如果是BlockNested-LoopJoin算法：在join_buffer_size足够大的时候，是一样的； 在join_buffer_size不够大的时候(这种情况更常见)，应该选择小表做驱动表。
- 在决定哪个表做驱动表的时候，应该是两个表按照各自的条件过滤，过滤完成之后，计算参与join的各个字段的总数据量，数据量小的那个表，就是“小表”，应该作为驱动表。

# 35 | join语句怎么优化?
- BKA优化是MySQL已经内置支持的，建议你默认使用；
- BNL算法效率低，建议你都尽量转成BKA算法。优化的方向就是给被驱动表的关联字段加上 索引；
- 基于临时表的改进方案，对于能够提前过滤出小数据的join语句来说，效果还是很好的；
- MySQL目前的版本还不支持hashjoin，但你可以配合应用端自己模拟出来，理论上效果要好 于临时表的方案。

# 36 | 为什么临时表可以重名?
- 临时表在使用上有以下几个特点:
  - 建表语法是create temporary table...。
  - 一个临时表只能被创建它的session访问，对其他线程不可见。由于临时表只能被创建它的session访问，所以在这个session结束的时候，会自动删除临时表。
  - 临时表可以与普通表同名。
  - sessionA内有同名的临时表和普通表的时候，show create语句，以及增删改查语句访问的是临时表。
  - show tables命令不显示临时表。
- 如果当前的binlog_format=row，那么跟临时表有关的语句，就不会记录到binlog 里。也就是说，只在binlog_format=statment/mixed 的时候，binlog中才会记录临时表的操作。
- 为什么不能用rename修改临时表的改名。在实现上，执行rename table语句的时候，要求按照“库名/表名.frm”的规则去磁盘找文件，但是临时表在磁盘上的frm文件是放在tmpdir目录下的，并且文件名的规则是“#sql{进程id}_{线程id}_ 序列号.frm”，因此会报“找不到文件名”的错误。

# 37 | 什么时候会使用内部临时表?
- 基于上面的union、union all和group by语句的执行过程的分析，我们来回答文章开头的问题: MySQL什么时候会使用内部临时表?
  - 如果语句执行过程可以一边读数据，一边直接得到结果，是不需要额外内存的，否则就需要额外的内存，来保存中间结果；
  - join_buffer是无序数组，sort_buffer是有序数组，临时表是二维表结构；
  - 如果执行逻辑需要用到二维表特性，就会优先考虑使用临时表。比如我们的例子中，union 需要用到唯一索引约束， group by还需要用到另外一个字段来存累积计数。
- 建议
  - 如果对group by语句的结果没有排序要求，要在语句后面加order by null；
  - 尽量让group by过程用上表的索引，确认方法是explain结果里没有Usingtemporary和Using filesort；
  - 如果group by需要统计的数据量不大，尽量只使用内存临时表；也可以通过适当调大tmp_table_size参数，来避免用到磁盘临时表；
  - 如果数据量实在太大，使用SQL_BIG_RESULT这个提示，来告诉优化器直接使用排序算法得到group by的结果。
