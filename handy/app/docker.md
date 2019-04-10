# docker 常用命令

```sh
docker rm containerid
docker exec -it containerid bash
docker run -p ip:hostPort:containerPort --env TERM='xterm' redis

docker build --pull --tag ${TAG} ./
docker push ${TAG}
```

## 保存镜像容器
保存，加载镜像命令，通过image保存的镜像会保存操作历史，可以回滚到历史版本。
```sh
docker save imageID > filename
docker load < filename
```

保存，加载容器命令：
```sh
docker export containID > filename
docker import filename [newname]
```

## docker pool 扩容
[enlarge-docker-pool.sh](./enlarge-docker-pool.sh)

## 清除废旧 image
[cleanup-unused-images.sh](./cleanup-unused-images.sh)
