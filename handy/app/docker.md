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

## enlarge docker pool

```sh
set -euo pipefail

SIZE=200 #GB

# Change file size
datafile=$(docker info | grep 'Data loop file' | awk '{print $NF}')
ls -lh $datafile
secnum=$(echo "$SIZE * 1024 * 1024 * 1024" | bc)
truncate -s $secnum $datafile
ls -lh $datafile

# Reload data loop device
blockdev --getsize64 /dev/loop0
losetup -c /dev/loop0
blockdev --getsize64 /dev/loop0

poolname=$(dmsetup status | grep pool | awk -F': ' '{print $1}')
poolinfo=$(dmsetup table $poolname)
newpoolinfo=$(echo $poolinfo | awk -v s=$SIZE '{
  for (i=1;i<NF;i++) {
    if (i==2)
      printf("%d ", s*1024*1024*1024/512);
    else
      printf("%s ", $i);
  }
  printf("%s", $NF)
}')

echo "Pool Info: $poolinfo"
echo "New Pool Info: $newpoolinfo"

dmsetup suspend "$poolname"
dmsetup reload "$poolname" --table "$newpoolinfo"
dmsetup resume "$poolname"
```
