# Dragon Chart

To install this chart to your current Kubernetes cluster context:

```
helm install ${RELEASE_NAME} . [-n $NAMESPACE]
```

To override Values, the `--set` flag can be used. For example, to set the number of compute nodes to 2:

```
helm install ${RELEASE_NAME} . [-n $NAMESPACE] --set backend.nnodes=2
```

To uninstall:

```
helm uninstall ${RELEASE_NAME} [-n $NAMESPACE]
```
