# mysql 配置

本地能连接，远程不能连接
- 修改数据配置，注释掉 `bind_address = 127.0.0.1`
- 修改数据库，`update user set host = '%' where user = 'root';`

