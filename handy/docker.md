# docker 常用命令

```sh
docker rm containerid
docker exec -it containerid bash
docker run -p ip:hostPort:containerPort --env TERM='xterm' redis

docker build --pull --tag ${TAG} ./
docker push ${TAG} 
```

## enlarge docker pool

```sh
#!/bin/bash
set -euo pipefail

SIZE=200 #GB

# Chagne file size.
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
newpoolinfo=$(echo $poolinfo | awk -v s=$SIZE '{for (i=1;i<NF;i++){if (i==2) printf("%d ", s*1024*1024*1024/512); else printf("%s ", $i);} printf("%s", $NF)}')
echo $poolinfo
echo $newpoolinfo

dmsetup suspend "$poolname"
dmsetup reload "$poolname" --table "$newpoolinfo"
dmsetup resume "$poolname"
```
