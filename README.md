# TechBook

个人技术资料整理，包括文章，读书笔记，常用工具等等。

目录在[这里](SUMMARY.md)

运行：
```sh
docker rm -f $(shell docker ps --filter "name=linlin-gitbook" --format "{{.ID}}")
docker run -d -v "$PWD:/gitbook" -p 4000:4000 --name liulin-gitbook \
  billryan/gitbook gitbook serve
```

