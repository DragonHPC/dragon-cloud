<img src="https://dragonhpc.org/wp-content/uploads/2025/03/Color-logo-no-background.png" width="600">

The GPU Cloud Service Batch service enables the running of functions, serial executables, and parallel applications that
supports complex data dependencies and manages task failures. Users access the batch service in one of several ways, including
via an interactive Juypter Python notebook.

# Post-Installation Steps

After successfully installing this application, the following steps should be taken to complete post-installation requirements.

## Setup Jupyter Notebook

During the installation and bring up of Jupyter, the DragonHPC application expects to find a named kubernetes secret
containing a token value to configure the Juypter engine with. Jupyter uses this token value to authenticate users trying to
access the Jupyter notebook.

Note: The creation and management of the jupyter token kubernetes secret is a manual process. The GPU Cloud Services Batch
application will not fully start until an appropriately named secret has been created.

### Prerequisites

1. Ensure that you have `kubectl` installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. Generate a safe and random token using the command below. Alternatively, you may use any hexadecimal string. It is
   suggested that any token be at least 16 characters long.

   ```
   python -c "import secrets; print(secrets.token_hex(16))"
   ```

2. Using `kubectl`, create a kubernetes secret containing the generated token value. The secret should be named
   `gpu-cloud-services-[NAME]-jupyter-token`, where `[NAME]` is the name used when installing this DragonHPC application.

   ```
   set APP_NAME= name_value
   set JUPYTER_TOKEN = token_value
   kubectl create secret generic gpu-cloud-services-$APP_NAME-jupyter-token \
    --from-literal=jupyter_token=$JUPYTER_TOKEN
   ```

3. Once the kubernetes secret has been created, the Dragon backend pods will be created.

## Configure access to Dragon Telemetry / Graphana

In order to access the Juypter notebook and telemetry services, several network tunnels must be created which allow your
local system to communicate with these services running within your Kubernetes cluster.

### Prerequisites

1. Ensure that you have `kubectl` installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. Execute the following command in a shell locally in your system to enable access to Juypter.

   ```
   kubectl port-forward svc/backend-pods-service 8888:8888
   ```

2. Execute the following command in a different shell locally in your system to enable access to Grafana.

   ```
   kubectl port-forward svc/grafana -n grafana-k8 3000:3000
   ```

# Open Jupyter Notebook and Grafana

## Steps

1. Open a browser window and go to `localhost:8888` to open the Juypter login page. When prompted, enter the token generated earlier to login.

2. Open a second browser window and go to `localhost:3000` to open Grafana.

# Run Batch Workload

## Steps

# Post-Uninstallation Steps

## Remove Juypter Secret

NOTE: This is an optional step. If you choose to not remove the Juypter secret, any subsequent installation of this DragonHPC
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
# Links

[dragonhpc.org](http://dragonhpc.org/)
[dragonhpc.slack.com](https://dragonhpc.slack.com/)
