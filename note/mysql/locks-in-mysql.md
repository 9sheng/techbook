```sql
CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `c`  int(11) DEFAULT NULL,
  `d`  int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `c` (`c`)
) ENGINE=InnoDB;

insert into t values(0,0,0), (5,5,5), (10,10,10), (15,15,15), (20,20,20), (25,25,25);
```

```sql
select * from t where c >= 15 and c <= 20 order by c desc for update;
```
1. 由于是order by c desc，第一个要定位的是索引c上“最右边的”c=20的行，所以会加上间隙锁 (20,25) 和next-key lock (15,20]。
1. 在索引c上向左遍历，要扫描到c=10才停下来，所以next-keylock会加到(5,10]。
1. 在扫描过程中，c=20、c=15、c=10这三行都存在值，由于是`select *`，所以会在主键id上加三个行锁。
1. 最后的锁： 索引c上 (5, 25)，主键索引上id=15、20两个行锁。


```sql
select * from t where c >= 15 and c <= 20 for update;
```
1. (10,15]
1. (15,20]
3. (20,25] -> (20,25)
4. [15],[20] 主键锁


```sql
update t set d = d+1 where id = 7;
```
1. (5,10] -> (5,10)


```sql
select id from t where c = 5 lock in share mode;
```
1. (0,5]
1. (5,10] -> (5,10)
1. 只锁了c上的索引
1. lock in share mode只锁覆盖索引，但是如果是for update就不一样 了。 执行 for update时，系统会认为你接下来要更新数据，因此会顺便给主键索引上满足条件的


```sql
select * from t where id=10 for update;
select * from t where id>=10 and id<11 for update;
```
1. (5,10] -> [10] 因为 id 为唯一索引
1. (10,15]
1. 首次session A定位查找id=10的行的时候，是当做等值查询来判断的，而向右扫描到id=15的时候，用的是范围查询判断。


```sql
select * from t where c >=  10 and c < 15 for update;
```
1. (5,10]
1. (10,15]


```sql
select * from t where id > 10 and id <= 15 for update;
```
1. (10, 15]
1. (15, 20] -> (15,20]  因为id是唯一索引，所以应该没有这个锁，但实际上 mysql 有这个锁，可能是个bug


```sql
insert into t values(30,10,30);
delete from t where c = 10;
```
1. (c=5,id=5)到(c=10,id=10)这个next-key lock
1. 退化成(c=10,id=10) 到 (c=15,id=15)的间隙锁


```sql
delete from t where c = 10 limit 2;
```
1. 索引c上的加锁范围就变成了从(c=5,id=5)到(c=10,id=30)这个前开后闭区间


```sql
select id from t where c = 10 lock in share mode
```
session B的“加next-key lock(5,10] ”操作，实际上分成了两步，先是加(5,10)的间隙锁，加锁成功;然后加c=10的行锁，这时候才被锁住的。
