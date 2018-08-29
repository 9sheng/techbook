# svn 常用操作

只 checkout 部分目录
```sh
# 先checkout空目录
svn co --depth empty svnLocation localDir
# 对需要的子目录递归checkout
svn update --set-depth infinity localDir/data
svn update --set-depth infinity localDir/block
```

## 一般开发流程
1. 创建分支
```sh
TRUNK='http://example.com/foo/trunk/bar'
BRANCH='http://example.com/foo/branches/bar-1.0.2-1'
svn copy $TRUNK $BRANCH -m "something"
```
2. 做一些修改，并提交到分支上
```sh
svn co $BRANCH $WORKDIR
svn commit -m "done"
```
3. 查询创建分支时的版本
```sh
svn log --stop-on-copy $BRANCH | awk '/^r/ {print $1}' | tail -1
```
4. 切换到主干
```sh
svn switch $TRUNK $WORKDIR
```
6. 合并分支，260为第3步输出的版本
```sh
svn merge -r260:HEAD $BRANCH $WORKDIR
```
7. 冲突解决
```sh
svn st | grep ^C      # 查找合并时的冲突文件，手工解决冲突
svn resolved filename # 告知 svn 冲突已解决
svn commit -m ""      # 提交并后的版本
```
