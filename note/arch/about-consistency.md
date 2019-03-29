# 关于一致性

# 一致性模型
正是由于分布式系统中多个实体或者多个备份的特点，才产生了一致性的概念。从字面意义上来说，『一致性』关注的是分布式系统中不同实体之间数据或者状态的一致程度；而从实际的角度来看，『一致性』其实反映了系统对 client 提供的服务所表现出的特征。

一般而言，分布式系统中的一致性按照从强到若可以分为四种：
1. Linearizability (Strong consistency or Atomic consistency)
   - 线性一致性又被称为强一致性或者原子一致性
2. Sequential consistency
3. Causal consistency
4. Eventual consistency

