set -euo pipefail

SIZE=200 #GB

# Change file size
echo "================================"
datafile=$(docker info | grep 'Data loop file' | awk '{print $NF}')
ls -lh $datafile
secnum=$(($SIZE * 1024 * 1024 * 1024))
truncate -s $secnum $datafile
ls -lh $datafile

echo "================================"
# Reload data loop device
blockdev --getsize64 /dev/loop0
losetup -c /dev/loop0
blockdev --getsize64 /dev/loop0

echo "================================"
poolname=$(dmsetup status | grep pool | awk -F': ' '{print $1}')
poolinfo=$(dmsetup table $poolname)
newpoolinfo=$(echo $poolinfo | awk -v s=$SIZE '{
  for (i=1; i<NF; i++) {
    if (i==2)
      printf("%d ", s*1024*1024*1024/512);
    else
      printf("%s ", $i);
  }
  printf("%s", $NF)
}')

echo "Old Pool Info: $poolinfo"
echo "New Pool Info: $newpoolinfo"

dmsetup suspend "$poolname"
dmsetup reload "$poolname" --table "$newpoolinfo"
dmsetup resume "$poolname"
