# kubectl 常用命令


去除 finalizers
```sh
kubectl patch authorizationactions -p '{"metadata":{"finalizers":[]}}'
```

查询特定的 event
```sh
kubectl get event -n base -owide \
  --field-selector involvedObject.kind=AuthorizationAction
```

查询 ownerReferences
```sh
kubectl get rs -o=jsonpath="{range .items[*]}{.metadata.namespace} \
  {.metadata.name} {.metadata.ownerReferences[0].name}{'\n'}{end}"
```

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

```sh
kubectl get pods -n xuri --sort-by=.status.startTime
kubectl get pods -n iflow -o wide --selector=app=admin-label

kubectl label node 10.152.82.24 zoon=z3
kubectl label node 10.152.88.106 pool-

kubectl scale sts mysql-local --replicas=2
kubectl exec bizsupervisor-web2wfc9 -n base -c bizsupervisor-web-init -it sh
```

https://kubernetes.io/docs/reference/kubectl/jsonpath/
