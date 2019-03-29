# kubectl 常用命令

pod 操作
```sh
kubectl get pods -n test --sort-by=.status.startTime
kubectl get pods -n test -o wide --selector=app=admin-label
kubectl exec -n test pod-web2wfc9 -c con-web-init -it sh
```

扩容操作
```sh
kubectl scale sts mysql-local --replicas=2
```

查询特定event
```sh
kubectl get event -n base -owide \
  --field-selector involvedObject.kind=AuthorizationAction
```

标签操作
```sh
kubectl label node 10.152.82.24 zoon=z3
kubectl label node 10.152.88.106 pool-
```

## 节点管理
标记节点unschedulable，并会驱逐节点上的pods
```sh
kubectl drain $NODE
```

阻止在该节点上调度新pod，但不会影响改节点上正在运行的pods
```sh
kubectl cordon $NODE
```

标记节点为schedulable状态
```sh
kubectl uncordon $NODE
```

## jsonpath
https://kubernetes.io/docs/reference/kubectl/jsonpath/

去除 finalizers
```sh
kubectl patch authorizationactions -p '{"metadata":{"finalizers":[]}}'
```
或者
```sh
kubectl patch authorizationactions --type json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

查询 ownerReferences
```sh
kubectl get rs -o=jsonpath="{range .items[*]}{.metadata.namespace} \
  {.metadata.name} {.metadata.ownerReferences[0].name}{'\n'}{end}"
```
