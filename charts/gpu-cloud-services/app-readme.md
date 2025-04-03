<img src="https://dragonhpc.org/wp-content/uploads/2025/03/Color-logo-no-background.png" width="600">

DragonHPC is a composable and distributed runtime that enables users to create scalable, complex, and resilient HPC and AI applications, workflows, and services through standard Python interfaces. Dragon provides capabilities to address many of the challenges around programmability, memory management, transparency, and efficiency on distributed computing systems.

# Post-Installation Steps

After successfully installing this application, the following steps should be taken to complete post-installation setup.

## Setup Juypter Notebook

During the installation and bring up of Juypter, the DragonHPC application expects to find a named kubernetes secret
containing the token, or password, value to configure the Juypter engine with. Juypter uses this token value to
authenticate users trying to access the Juypter notebook.

Note: The creation and management of the juypter token kubernetes secret is a manual process.

### Prerequisites

1. Ensure that you have kubectl installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. Using `kubectl`, create a kubernetes secret containing the token value to use. The secret should be named
   `dragon-[NAME]-juypter-token`, where `[NAME]` is the name used when installing this DragonHPC application.

   ```bash
   # set RELEASE_NAME=<RELEASE_NAME>
   # kubectl create secret generic dragon-$RELEASE_NAME-jupyter-token \
    --from-literal=username=admin
   ```

## Configure access to Dragon Telemetry / Graphana

TBD

# Post-Uninstallation Steps

## Remove Juypter Secret

NOTE: This is an optional step. If you choose to not remove the Juypter secret, any subsiquent installation of this DragonHPC
application, using the same installation name, will use the pre-configured Juypter secret. This can be beneficial for teams
that share a common Juypter notebook.

### Prerequisites

1. Ensure that you have kubectl installed and that it is properly configured to access your kubernetes cluster.

### Steps

1. Using `kubectl`, delete the previously created secret.

   ```bash
   # set RELEASE_NAME=<RELEASE_NAME>
   # kubectl delete secret dragon-$RELEASE_NAME-jupyter-token
   ```
## Remove access to Dragon Telemetry / Graphana

TBD

# Links

[dragonhpc.org](http://dragonhpc.org/)
[dragonhpc.slack.com](https://dragonhpc.slack.com/)
