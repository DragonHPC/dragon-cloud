<img src="https://dragonhpc.org/wp-content/uploads/2025/03/Color-logo-no-background.png" width="600">

# DragonHPC Jupyter

This is an **example** chart. It starts a [Dragon](https://dragonhpc.org) runtime across several pods and runs a Jupyter
server inside it. Notebook code can use Dragon's distributed `multiprocessing`, Distributed Dictionary, and other APIs,
and that work runs on all backend pods.

Before you install, set the container image and create a `ReadWriteMany` PersistentVolumeClaim named `dragon-shared`
(or point the chart at your own claim). You may also need to adjust GPU resources and tolerations for your cluster. The
chart README describes these values.

## Before installing

Jupyter needs a login token. The chart reads it from a Kubernetes Secret named
`dragonhpc-jupyter-<RELEASE_NAME>-jupyter-token`. Backend pods don't start until this Secret exists, so create it
before you install:

```bash
export RELEASE_NAME=<release name, 11 characters or fewer>
export NAMESPACE=<target namespace>
python3 -c "import secrets; print(secrets.token_hex(16))" | \
  kubectl create secret generic dragonhpc-jupyter-${RELEASE_NAME}-jupyter-token \
    -n ${NAMESPACE} --from-file=jupyter_token=/dev/stdin
```

## After installing

1. Wait until the backend pods are `Running`:

   ```bash
   kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}
   ```

2. Forward the Jupyter Service to your machine:

   ```bash
   kubectl port-forward -n ${NAMESPACE} svc/backend-pods-service 8888:8888
   ```

3. Open <http://localhost:8888>. To log in, use the token stored in the Secret:

   ```bash
   kubectl get secret dragonhpc-jupyter-${RELEASE_NAME}-jupyter-token -n ${NAMESPACE} \
     -o jsonpath='{.data.jupyter_token}' | base64 -d
   ```

## After uninstalling

Helm doesn't manage the token Secret, so `helm uninstall` leaves it in place. If you install again with the same release
name, the chart uses the same token. To delete the Secret:

```bash
kubectl delete secret dragonhpc-jupyter-${RELEASE_NAME}-jupyter-token -n ${NAMESPACE}
```

## Links

- [Dragon documentation](https://dragonhpc.github.io/dragon/doc/_build/html/index.html)
- [Dragon source code](https://github.com/DragonHPC/dragon)
- [dragonhpc.org](https://dragonhpc.org/)
- To join the [DragonHPC Slack](https://dragonhpc.slack.com/), email [dragonhpc@hpe.com](mailto:dragonhpc@hpe.com).
