# TechBook

个人技术资料整理，包括文章，读书笔记，常用工具等等。

目录在[这里](SUMMARY.md)

run with image `https://hub.docker.com/r/billryan/gitbook/`
```sh
# init
docker run --rm -v "$PWD:/gitbook" -p 4000:4000 billryan/gitbook gitbook init
# serve
docker run --rm -v "$PWD:/gitbook" -p 4000:4000 --name gitbook billryan/gitbook gitbook serve
# build
docker run --rm -v "$PWD:/gitbook" -p 4000:4000 billryan/gitbook gitbook build
```

