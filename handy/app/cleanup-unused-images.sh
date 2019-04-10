set -euo pipefail

docker images | awk '/months ago/{printf("%s\n", $3)}' | \
  sort | uniq > all-images.txt
docker images > images-info.txt
docker inspect --format='{{.Image}} {{.Name}}' $(sudo docker ps -aq) | \
  awk -F':' '{print $2}' | sort | uniq > running-images.txt
while read line
do
  grep -q "$line" running-images.txt && ret=$? || ret=$?
  if [ $ret -ne 0 ]; then
    grep $line images-info.txt
    docker rmi $line
  fi
done < all-images.txt
rm -rf images-info.txt all-images.txt running-images.txt
