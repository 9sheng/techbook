# git 使用小结

## 一般流程
假设需要开发某个功能，或者 fix 某个 bug，详细如下： 

1.更新代码
在做所有开发工作之前，先把本地代码和 git repos 同步最新：
```sh  
git pull
```

2.修改代码
本地 coding, coding 过程中，可能会有多次本地 commit，比如说， coding balabalabala，然后：
```sh
git add . 
git commit 
```
再 coding，然后 
```sh
git add . 
git commit 
```
  
3.提交代码
假设 coding 完成，需要把本地代码推送到远端 git repos，在推送之前，一定做如下动作： 
```sh
git pull --rebase 
```
在这一步，一定不要简单的执行 `git pull`，`git pull` 相当于两个动作，先 `git featch`, 然后 `git merge`；如果本地有冲突，这样会造成本地新创建一个分支出来。如果接着把这样没有意义的分支推送到远端 git repos，会导致整个 git tree 很难看。 
  
在你 coding 期间，别人可能提交代码，提交的代码可能和你 coding 的内容冲突，如果有冲突，会给你提示，类似前面说得， 
```
<<<<<<< HEAD  
......
=======
...... 
>>>>>>> branch 'master' of ......
``` 
有冲突没关系，找到相应冲突的地方，按照提示修改就好了。改完以后做如下动作， 
```sh
git add . 
git commit 
```
然后根据提示做 
```sh
git rebase --continue 
```
完成冲突解决以后就可以把本地 coding 内容 push 到远端 git repos 了 

```sh
git push
```

## 有用的命令

### 创建新仓库
```sh
git init
```

检出仓库
```sh
git clone /path/to/repository # 本地仓库 
git clone username@host:/path/to/repository #远程仓库
```

### 远端
```sh
git remote -v # 查看远端
git remote set-url origin http://sogou.git # 设置远程源
git push -u origin master # 推本地分支到远端
# 拉取远程分支
git checkout -b v0.0.1 remotes/origin/v0.0.1
git checkout -t origin/v0.0.1
```


如果你还没有克隆现有仓库，并欲将你的仓库连接到某个远程服务器，你可以使用如下命令添加：
```sh
git remote add origin <server>
git push origin master
```

git 同步父流更新
```sh
git remote add upstream https://github.com/被fork的仓库.git
git fetch upstream
git merge upstream/master
```

强制推送本地库到服务器
```sh
git push origin HEAD --force
```

### 标签
```sh
git tag # 查看标签
git tag -a v1.1.0 084ac46 # 增加标签
git show v1.1.0 # 查看标签
git push origin v1.1.0 # 推到远端
```

### 打包导出
```sh
git archive --format zip -o site-$(git log --pretty=format:"%h" -1).zip HEAD
git archive v0.1 | gzip > site.tgz
```

### 彩色显示
```sh
git config --global color.status auto
git config --global color.diff auto
git config --global color.branch auto
git config --global color.interactive auto
```

### 非交互式
```sh
git config --global pager.branch false
# git diff using no pager
git config --global --replace-all core.pager "less -F -X"
```

### 恢复修改
本地修改了许多文件，其中有些是新增的，因为开发需要这些都不要了，想要丢弃掉，可以使用如下命令：
```sh
git checkout .  # 本地所有修改的文件，没有的提交的，都返回到原来的状态
git checkout -- <filename>
git stash # 把所有没有提交的修改暂存到stash里面。可用git stash pop恢复
git reset --hard HASH # 返回到某个节点，不保留修改
git reset --soft HASH # 返回到某个节点。保留修改
git clean -df # 返回到某个节点，-n 显示将要删除的文件和目录，-f 删除文件，-df 删除文件和目录
```

缓存修改
修改了一些东西，想切换到另一个分支：
```sh
git stash # 保存工作 
git stash list # 查看 
git stash apply # 恢复stash ，默认stash@{0} 
git stash apply stash@{2}
```

假如你想要丢弃你所有的本地改动与提交，可以到服务器上获取最新的版本并将你本地主分支指向到它：
```sh
git fetch origin
git reset --hard origin/master
```

### cherry pick 
当执行完 cherry-pick 以后，将会生成一个新的提交；这个新的提交的哈希值和原来的不同，但标识名一样；
```sh
git cherry-pick 38361a55 
```
