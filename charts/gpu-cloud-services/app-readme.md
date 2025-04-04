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

## Getting Started

The Batch service allows users to compile a sequence of calls to Python functions, executables, and parallel jobs into a single
task that the user can start and wait on. Below is a simple example using `Batch` to create a DAG representing the parallelization
of a list of functions.

    # Generate the powers of a matrix and write them to disk
    from alamo import Batch
    from pathlib import Path
    import numpy as np

    # A base directory, and files in it, will be used for communication of results
    batch = Batch()
    base_dir = Path("/some/path/to/base_dir")

    # Knowledge of reads and writes to files will also be used by the Batch service
    # to determine data dependencies and how to parallelize tasks
    reads = lambda i: batch.read(base_dir, Path(f"file_{i}"))
    writes = lambda i: batch.write(base_dir, Path(f"file_{i+1}"))

    a = np.array([j for j in range(100)])
    m = np.vander(a)

    # batch.function will create a task with specified arguments and reads/writes to the file system
    get_task = lambda i: batch.function(gpu_matmul_func, (m, base_dir, i), reads(i), writes(i))

    # Package up the list of tasks into a single compiled task and create the DAG (done by batch.compile),
    # and then submit the compiled task to the Batch service (done by matrix_powers_task.start)
    matrix_powers_task = batch.compile([get_task(i) for i in range(1000)])
    results_dict = matrix_powers_task.start()

    # Wait for the compiled task to complete
    matrix_powers_task.wait(timeout=30)

    # If there was an exception while running the task, it will be raised when get() is called
    for result, stdout, stderr in results_dict.values():
        try:
            print(f"result={result.get()}")
            # print(f"stdout={stdout.get()}")
            # print(f"stderr={stderr.get()}")
        except Exception as e:
            print(f"gpu_matmul_func failed with the following exception: {e}")

    batch.close()
    batch.join()

The `Batch.compile` operation assumes that the order of functions in the list represents a valid order in which a user would
manually call the functions in a sequential program. Given the list of functions, `Batch.compile` will produce a DAG that
contains all the information needed to efficiently parallelize the function calls. Calling `matrix_powers_task.start` will
submit the *compiled* task to the Batch service, and calling `matrix_powers_task.wait` will wait for the completion of the task.
The functions `Batch.close` and `Batch.join` are similar to the functions in `multiprocessing.Pool` with the same names--`Batch.close`
lets the Batch service know that no more work will be submitted, and `Batch.join` waits for all work submitted to the Batch service
to complete and for the service to shut down.

Individual (i.e., non-compiled) tasks can also be submitted to the Batch service, but batching tasks together via `Batch.compile`
will generally give better performance in terms of task scheduling overhead. There is no guaranteed ordering between separate tasks
submitted to the Batch service. So, for example, if a user submits several compiled and non-compiled tasks to the Batch service,
they will be executed in parallel and in no particular order.

Any mix of Python functions, executables, and parallel jobs can be submitted to the Batch service simulataneously, and dependencies
can exist between tasks of any type, e.g., an MPI job can depend on the completion of a Python function if the MPI job reads from
a file that the function writes to. MPI jobs are specified using the `Batch.job` function, which will create a task that allows
the user to run the specified job. Likewise, the `Batch.process` function creates a task for running a serial executable. All tasks,
regardless of the type of code that they run, have the same interface: `Task.start` to start a task without waiting for its completion;
`Task.wait` to wait for the completion of a task; `Task.run`, a blocking variant of `Task.start`, to both start a task and wait for its
completion; and `get` is used to get the result, stdout, or stderr of a task. Calling `start` or `run` for individual tasks will return
a tuple of three handles: `result`, `stdout`, and `stderr`, all of type `AsyncValue`. Calling the `get` method for any of these handles
gets the associated value, and waits for the completion of the task if necessary. For compiled tasks, calling `start` or `run` will
return a dictionary of these tuples, where the key for a tuple is the UID of its task (obtained by calling `Task.get_uid()`). If an
exception was thrown during the execution of a task, then calling `AsyncValue.get()` for the `result`, `stdout`, or `stderr` of the
task will raise the same exception that was thrown by the task.

The initial creation of the `Batch` object sets up manager and worker processes that implement an instance of the Batch service.
`Batch` objects can be passed between processes to allow multiple clients to use the Batch service. Unpickling a `Batch` object
at a destination process will register the new `Batch` client with the Batch service and allow the user to submit tasks to it.
All clients must call `Batch.close` to indicate that they are done with the Batch service. Only the primary client (which created
the initial `Batch` object) needs to call `Batch.join`. Note that `Batch.join` will block until all clients have called `Batch.close`.

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
