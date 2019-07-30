# 11 | 怎么给字符串字段加索引?
- 直接创建完整索引，这样可能比较占用空间;
- `alter table SUser add index index2(email(6));` 创建的index2 索引里面，对于每个记录都是只取前6个字节。直接创建完整索引，这样可能比较占用空间;
- 使用前缀索引就用不上覆盖索引对查询性能的优化了，这也是你在选择是否使用前缀 索引时需要考虑的一个因素。回表带来的性能损失。
- 如果我们能够确定业务需求里面只有按照身份证进行等值查询的需求，还有没有别的处理 方法呢?这种方法，既可以占用更小的空间，也能达到相同的查询效率。
  - 第一种方式是使用倒序存储。`select field_list from t where id_card = reverse('input_id_card_string');`
  -  第二种方式是使用hash字段。`alter table t add id_card_crc int unsigned, add index(id_card_crc);` 然后每次插入新记录的时候，都同时用crc32()这个函数得到校验码填到这个新字段

# 12 | 为什么我的MySQL会“抖”一下?
- 你不难想象，平时执行很快的更新操作，其实就是在写内存和日志，而MySQL偶尔“抖”一下的那个瞬间，可能就是在刷脏页(flush)。
- flush 的时机
  - 对应的就是InnoDB的redo log写满了。这时候系统会停止所有更新操作，把 checkpoint往前推进，redo log留出空间可以继续写。
    - “redo log写满了，要flush脏页”，这种情况是InnoDB要尽量避免的。因为出现这种情况 的时候，整个系统就不能再接受更新了，所有的更新都必须堵住。如果你从监控上看，这时候更 新数会跌为0。
  - 对应的就是系统内存不足。当需要新的内存页，而内存不够用的时候，就要淘汰一些数据页，空出内存给别的数据页使用。如果淘汰的是“脏页”，就要先将脏页写到磁盘。
  - 对应的就是MySQL认为系统“空闲”的时候。
  - 对应的就是MySQL正常关闭的情况。这时候，MySQL会把内存的脏页都flush到磁 盘上，这样下次MySQL启动的时候，就可以直接从磁盘上读数据，启动速度会很快。
- InnoDB刷脏页的控制策略
  - innodb_io_capacity这个参数了，它会告诉InnoDB你的磁盘能力。这个值我建议你设 置成磁盘的IOPS。磁盘的IOPS可以通过fio这个工具来测试
  - 参数innodb_max_dirty_pages_pct是脏页比例上限，默认值是75%。InnoDB会根据当前的脏页比例(假设为M)，算出一个范围在0到100之间的数字
  - 要尽量避免这种情况，你就要合理地设置innodb_io_capacity的值，并且平时要多关注脏页比 例，不要让它经常接近75%。

```sql
-- 计算脏页比例
select VARIABLE_VALUE into @a from global_status where VARIABLE_NAME = 'INNODB_BUFFER_POOL_PAGES_DIRTY'
select VARIABLE_VALUE into @b from global_status where VARIABLE_NAME = 'INNODB_BUFFER_POOL_PAGES_TOTAL'
select @a/@b;
```

一旦一个查询请求需要在执行过程中先flush掉一个脏页时，这个查询就可能要比平时慢了。而 MySQL中的一个机制，可能让你的查询会更慢:在准备刷一个脏页的时候，如果这个数据页旁 边的数据页刚好是脏页，就会把这个“邻居”也带着一起刷掉;而且这个把“邻居”拖下水的逻辑还 可以继续蔓延。在InnoDB中，innodb_flush_neighbors 参数就是用来控制这个行为的，值为1的时候会有上述 的“连坐”机制，值为0时表示不找邻居，自己刷自己的。如果使用的是SSD这类IOPS比较高的设备的话，我就建议你把innodb_flush_neighbors的值 设置成0。在MySQL 8.0中，innodb_flush_neighbors参数的默认值已经是0了。

#13 | 为什么表数据删掉一半，表文件大小不变?
- 表数据既可以存在共享表空间里，也可以是单独的文件。这个行为是由参数 innodb_file_per_table控制的,将innodb_file_per_table设置为ON，是推荐做法, 这个参数设置为ON表示的是，每个InnoDB表数据存储在一个以 .ibd为后缀的文件中。
- delete命令其实只是把记录的位置，或者数据页标记为了“可复用”，但磁盘文件 的大小是不会变的。也就是说，通过delete命令是不能回收表空间的。这些可以复用，而没有被 使用的空间，看起来就像是“空洞”。
- 可以使用 `alter table A engine=InnoDB` 命令来重建表。在MySQL 5.5版本之前，这个命 令的执行流程跟我们前面描述的差不多，区别只是这个临时表B不需要你自己创建，MySQL会自 动完成转存数据、交换表名、删除旧表的操作。花时间最多的步骤是往临时表插入数据的过程，如果在这个过程中，有新的数据要写入到表A的话，就会造成数据丢失。因此，在整个DDL过程中，表A中不能有更新。也就是说，这个 DDL不是Online的。 
- 线上执行这个过程，如果想要比较安全的操作的话，我推荐你使用GitHub开源的gh-ost来做。
- 根据表A重建出来的数据是放在“tmp_file”里的，这个临时文件是InnoDB在内部创建出 来的。整个DDL过程都在InnoDB内部完成。对于server层来说，没有把数据挪动到临时表，是 一个“原地”操作，这就是“inplace”名称的来源。
- 号外
  - 从MySQL 5.6版本开始，`alter table t engine = InnoDB`(也就是recreate)默认的就是上面图4 的流程了;
  - `analyze table t` 其实不是重建表，只是对表的索引信息做重新统计，没有修改数据，这个过程 中加了MDL读锁;
  - `optimize table t` 等于recreate+analyze。
- 为什么 `alter table t engine = InnoDB` 之后表变大了？
  - 大家都提到了一个点，就是这个表，本身就已经没有空洞的了，比如说刚刚做过一次重建表操作。
  - 在DDL期间，如果刚好有外部的DML在执行，这期间可能会引入一些新的空洞。
  - 在重建表的时候，InnoDB不会把整张表占满，每个页留了1/16给后续的更新用。也就是说，其实重建表之后不是“最”紧凑的。

# 14 | `count(*)`这么慢，我该怎么办?
- MyISAM引擎把一个表的总行数存在了磁盘上，因此执行`count(*)`的时候会直接返回这个数， 效率很高;
- 而InnoDB引擎就麻烦了，它执行`count(*)`的时候，需要把数据一行一行地从引擎里面读出 来，然后累积计数。
- 为什么InnoDB不跟MyISAM一样，也把数字存起来呢? 这是因为即使是在同一个时刻的多个查询，由于多版本并发控制(MVCC)的原因，InnoDB表“应该返回多少行”也是不确定的。
- show table status命令显示的行 数也不能直接代替 `count(*)`，里面的 TABLE_ROWS 是采样估计值。
- 把计数放在Redis里面，不能够保证计数和MySQL表里的数据精确一致的原因，是这两个不同的存储构成的系统，不支持分布式事务，无法拿到精确一致的视图。而把计数值也放在 MySQL中，就解决了一致性视图的问题。计数值和业务在事务里统一更新。
- 性能排序：按照效率排序的话，`count(字段)<count(主键id)<count(1)≈count(*)`，所以我建议你，尽量使用`count(*)`。

# 15 | 答疑文章(一):日志和索引相关问题
- MySQL怎么知道binlog是完整的? 一个事务的binlog是有完整格式的: statement格式的binlog，最后会有COMMIT; row格式的binlog，最后会有一个XID event。
- 如果是现在常见的几个TB的磁盘的话，就不要太小气了，直接将redo log设置为4个文件、每个文件1GB吧。
- 真正把日志写到redo log文件(文件名是 ib_logfile+数字)，是在执行commit语句的时候做的。

# 16 | “order by”是怎么工作的?
- 全字段排序： sort_buffer_size，就是MySQL为排序开辟的内存(sort_buffer)的大小。如果要排序的数据量 小于sort_buffer_size，排序就在内存中完成。但如果排序数据量太大，内存放不下，则不得不 利用磁盘临时文件辅助排序。sort_buffer_size，就是MySQL为排序开辟的内存(sort_buffer)的大小。如果要排序的数据量 小于sort_buffer_size，排序就在内存中完成。但如果排序数据量太大，内存放不下，则不得不 利用磁盘临时文件辅助排序。
- rowid排序：max_length_for_sort_data，是MySQL中专门控制用于排序的行数据的长度的一个参数。它的意 思是，如果单行的长度超过这个值，MySQL就认为单行太大，要换一个算法。新的算法放入sort_buffer的字段，只有要排序的列sort_key 和主键id，然后回表读取所有的字段。
- 可以优化索引，譬如设置覆盖索引，但维护覆盖索引也有代价，需要权衡。

# 17 | 如何正确地显示随机消息?
- 直接使用order by rand()，这个语句需要Using temporary 和 Using filesort，查询的执行代价往往是比较大的。所以，在设计的时候你要量避开这种写法。
   - 从words表中，按主键顺序取出所有的word值。对于每一个word值，调用rand()函数生成一 个大于0小于1的随机小数，并把这个随机小数和word分别存入临时表的R和W字段中
- 内存临时表：对于内存表，回表过程只是简单地根据数据行的位 置，直接访问内存得到数据，不会导致多访问磁盘。
- 磁盘临时表：tmp_table_size这个配置限制了内存临时表的大小，默认值是16M。如果临时表大小超过了tmp_table_size，那么内存临时表就会转成磁盘临时表。
-  MySQL 5.6版本引入的一个新的排序算法， 即:优先队列排序算法。
- 随机排序的方法（随机不均匀）
  1. 取得这个表的主键id的最大值M和最小值N;
  1. 用随机函数生成一个最大值到最小值之间的数X=(M-N)*rand()+N;
  1. 取不小于X的第一个ID的行。
- 随机排序的方法2，扫表多

```sql
-- 按顺序一个一个地读出来，丢掉前Y个，然后把下一个记录作为 返回结果，
-- 因此这一步需要扫描Y+1行。再加上，第一步扫描的C行，总共需要扫描C+Y+1行
select count(*) into @C from t;
set @Y = floor(@C * rand());
set @sql = concat("select * from t limit ", @Y, ",1");
prepare stmt from @sql;
execute stmt;
deallocate prepare stmt;
```

# 18 | 为什么这些SQL语句逻辑相同，性能却差异巨大?
- 条件字段函数操作
  - `select count(*) from tradelog where month(t_modified)=7;` 不使用 t_modified 的索引
  - `select * from tradelog where id + 1 = 10000` 也不会用 id 上的索引
- 隐式类型转换
  - `select * from tradelog where tradeid=110717;`  tradeid的字段类型是varchar(32)，默认的会将字符串转换成数字
- 隐式字符编码转换：和条件字段函数类似，但这里是隐式的字符集转换。
  - ` select d.* from tradelog l , trade_detail d where d.tradeid=CONVERT(l.tradeid USING utf8) and l.id =2;`
  - 在这个执行计划里，是从tradelog表中取tradeid字段，再去trade_detail表里查询匹配字段。因此，我们把tradelog称为驱动表，把trade_detail称为被驱动表，把tradeid称为关联字段。
- 时间上MySQL优化器执行过程中，where 条件部分， a=b和 b=a的写法是一样的。

# 19 | 为什么我只查一行的语句，也执行这么慢?
- MetaData Lock即元数据锁，在数据库中元数据即数据字典信息包括db,table,function,procedure,trigger,event等。Metadata lock主要为了保证元数据的一致性,用于处理不同线程操作同一数据对象的同步与互斥问题。
- 查询长时间不返回
  - 等MDL锁：`show processlist`检测
  - 等flush `flush tables t with read lock;` `flush tables with read lock;`
  - 等行锁：用下面的语言检测
 ```
select * from t sys.innodb_lock_waits where locked_table=`'test'.'t'`\G
```
- 查询慢
  - `select * from t where c=50000 limit 1;`
  - `select * from t where id=1;` 800ms,   `select * from t where id=1 lock in share mode`，执行时扫描行数也是1行，执行时间是0.2毫秒，原因第一条 sql，一致性读，undo log 太多，第2条sql 是当前读很快（循环执行 100万次 `update t set c=c+1 where id = 1`）

# 20 | 幻读是什么，幻读有什么问题?
- 幻读指的是一个事务在前后两次查 询同一个范围的时候，后一次查询看到了前一次查询没有看到的行
- 幻读有什么问题?
  - 首先是语义上的。session A在T1时刻就声明了，“我要把所有d=5的行锁住，不准别的事务进行读写操作”。而实际上，这个语义被破坏了。
  - 其次，是数据一致性的问题。
- 产生幻读的原因是，行锁只能锁住行，但是新插入记录这个动作，要更新的是记 录之间的“间隙”。因此，为了解决幻读问题，InnoDB只好引入新的锁，也就是间隙锁(Gap Lock)，gap 加在对应的索引上？。
- 行锁有冲突关系的是“另外一个行锁”。但是间隙锁不一样，跟间隙锁存在冲突关系的，是“往这个间隙中插入一个记录”这个操 作。
- 间隙锁和行锁合称next-key lock，每个next-key lock是前开后闭区间。也就是说，我们的表t初始 化以后，如果用select * from t for update要把整个表所有记录锁起来，就形成了7个next-key lock，分别是 (-∞,0]、(0,5]、(5,10]、(10,15]、(15,20]、(20, 25]、(25, +supremum]。
- 间隙锁是在可重复读隔离级别下才会生效的。所以，你如果把隔离级别设置为读提交的话， 就没有间隙锁了。但同时，你要解决可能出现的数据和日志不一致问题，需要把binlog格式设置 为row。这也是现在不少公司使用的配置组合。

>事务提交时候才能看到 binlog？
