<img src="https://dragonhpc.org/wp-content/uploads/2025/03/Color-logo-no-background.png" width="600">

The GPU Cloud Services Batch is a composable and distributed runtime that enables users to


create scalable, complex, and resilient HPC and AI applications, workflows, and services through standard Python interfaces. Dragon provides capabilities to address many of the challenges around programmability, memory management, transparency, and efficiency on distributed computing systems.

# Post-Installation Steps

After successfully installing this application, the following steps should be taken to complete post-installation setup.

## Setup Jupyter Notebook

During the installation and bring up of Jupyter, the DragonHPC application expects to find a named kubernetes secret
containing the token, or password, value to configure the Juypter engine with. Jupyter uses this token value to
authenticate users trying to access the Jupyter notebook.

Note: The creation and management of the jupyter token kubernetes secret is a manual process.

### Prerequisites

1. Ensure that you have `kubectl` installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. The user can use the following command to generate a safe and random token:
   ```
   python -c "import secrets; print(secrets.token_hex(16))"
   ```
2. Using `kubectl`, create a kubernetes secret containing the token value to use. The secret should be named
   `dragon-[NAME]-jupyter-token`, where `[NAME]` is the name used when installing this DragonHPC application.

   ```
   set APP_NAME= value
   set JUPYTER_TOKEN= value
   kubectl create secret generic gpu-cloud-services-$APP_NAME-jupyter-token \
    --from-literal=jupyter_token=$JUPYTER_TOKEN
   ```
3. Once the kubernetes secret has been created, the Dragon backend pods will be created.

## Configure access to Dragon Telemetry / Graphana

In order to access the Jupyter Notebook, you need to execute the following command in a shell locally in your system:

```
kubectl port-forward svc/backend-pods-service 8888:8888
```

In order to access Grafana, you need to execute the following command in a different shell locally in your system:

```
kubectl port-forward svc/grafana -n grafana-k8 3000:3000
```

# Open Jupyter Notebook and Graphana

## Steps

In order to access the Jupyter Notebook, you open your browser and go to `localhost:8888`. There, you will need to provide the token you generated earlier to login.
In order to access Grafana, you open a separate browser window and go to `localhost:3000`.

# Run Batch Workload

# Steps

# Post-Uninstallation Steps

## Remove Juypter Secret

NOTE: This is an optional step. If you choose to not remove the Juypter secret, any subsiquent installation of this DragonHPC
application, using the same installation name, will use the pre-configured Juypter secret. This can be beneficial for teams
that share a common Juypter notebook.

### Prerequisites

1. Ensure that you have kubectl installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. Using `kubectl`, delete the previously created secret.

   ```
   export set APP_NAME= value
   kubectl delete secret gpu-cloud-services-$APP_NAME-jupyter-token
   ```

## Remove access to Dragon Telemetry / Graphana

TBD

# Links

[dragonhpc.org](http://dragonhpc.org/)
[dragonhpc.slack.com](https://dragonhpc.slack.com/)
