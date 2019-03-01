http://10.143.62.161:6060/debug/pprof/
http://10.143.62.161:6060/debug/pprof/goroutine?debug=2

```sh
go tool pprof 'http://10.143.62.161:6060/debug/pprof/profile?seconds=60'
go tool pprof 'http://10.143.62.161:6060/debug/pprof/heap'
```
