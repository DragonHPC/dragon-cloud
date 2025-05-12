<a id="alamo.batch.batch"></a>

# GPU Cloud Services

Scalable services for interacting with the GPU Cloud Service, including Batch, Queue, and Distributed Dictionary services.

## Getting Started

### Batch

The Batch service allows users to compile a sequence of tasks (Python functions, executables, or parallel jobs) into a single
task that the user can start and wait on. Users can specify dependencies between tasks and the Batch service will automatically
parallelize them via an imlicitly inferred directed acyclic graph (DAG). The big picture idea is that the Batch service allows
users to think sequentially while reaping the benefits of a parallelized work flow.

Below is a simple example using `Batch` to parallelize a list of functions. In this simple example, dependencies actually force
the functions to execute serially, but it demonstrates the basics of the API.

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
    serial_task_list = [get_task(i) for i in range(1000)]
    matrix_powers_task = batch.compile(serial_task_list)
    matrix_powers_task.start()

    # Wait for the compiled task to complete
    matrix_powers_task.wait(timeout=30)

    # If there was an exception while running the task, it will be raised when get() is called
    for task in serial_task_list:
        try:
            print(f"result={task.result.get()}")
            # print(f"stdout={task.stdout.get()}")
            # print(f"stderr={task.stderr.get()}")
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
the user to run the specified job. Likewise, the `Batch.process` function creates a task for running a serial executable. Avoid using
the `Task` class directly to create tasks.

All tasks, regardless of the type of code that they run, have the same interface: `Task.start` to start a task without waiting for its completion;
`Task.wait` to wait for the completion of a task; `Task.run`, a blocking variant of `Task.start`, to both start a task and wait for its
completion; and handles for getting the result, stdout, or stderr of a task. Tasks have three handles for obtaining output: `result`,
`stdout`, and `stderr`, all of type `AsyncDict`. Calling the `get` method for any of these handles gets the associated value, and waits
for the completion of the task if necessary. For individually started tasks, subtasks of a compiled task, and compiled tasks with a
single subtask `get` does not require any arguments--it always returns the output for the given task. For compiled tasks with more than
one subtask, calling `get` for any of the output handles requires the unique ID of the desired subtask (`Task.uid`). If an exception was
thrown during the execution of a task, then calling `AsyncDict.get()` for the `result` handle of the task will raise the same exception
that was thrown by the task.

The initial creation of the `Batch` object sets up manager and worker processes that implement an instance of the Batch service.
`Batch` objects can be passed between processes to allow multiple clients to use the Batch service. Unpickling a `Batch` object
at a destination process will register the new `Batch` client with the Batch service and allow the user to submit tasks to it.
All clients must call `Batch.close` to indicate that they are done with the Batch service. Only the primary client (which created
the initial `Batch` object) needs to call `Batch.join`. Note that `Batch.join` will block until all clients have called `Batch.close`.

#### Data Dependencies

Dependencies between tasks are inferred based on the data being read and written by each task. Data reads and writes are specified
by `Batch.read` and `Batch.write` (or `Task.read` and `Task.write`, to directly associate reads and writes with a specific task).
When a task is created, a list of Read or Write objects, created by `Batch.read` and `Batch.write`, can be specified:

    task = batch.job(target=mpi_exec, num_procs=256, reads=<list of Reads>, writes=<list of Writes>)

After a task has been create, further Reads and Writes can be specified via `task.read` and `task.write`:

    task.read(base_dir1, file_path1)
    task.write(base_dir2, file_path2)

The Batch service takes a *dataflow* approach to parallelizing tasks. Like all dataflow systems, it assumes that tasks have no
[*side effects*](https://en.wikipedia.org/wiki/Side_effect_(computer_science)) (think IO) beyond those specified by `Batch.read`
and `Batch.write` calls. So, for instance, if a process task reads from a file, then a corresponding Read object must be created
using `Batch.read` and appended to the list of Reads when creating the task (or added after task creation using `task.read`). If
this Read isn't associated with the task, and the task is part of a compiled task, then the file read could happen out-of-order
relative to other operations on that file, e.g., the file read could occur before the data intended to be read is written to the
file.

<!---
If your tasks do any IO beyond these three options, and you feel comfortable with dataflow concepts, then the Batch service provides
custom *communication objects* that can help you with your use case. A communication object can be a Distributed Dictionary, a `Path`
specifying a directory in a file system, a Queue, or a user-defined communication object. A *channel* is an abstaction for keys in a
Distributed Dictionary, files in a directory, etc. There can be one or more channels associated with a communication object, i.e.,
there are many keys for a Distributed Dictionary, but only a single default channel for a Queue. A communication object and zero or
more communication channels are passed to `Batch.read` and `Batch.write`. A custom communication object can be created using the
`CommunicationDomain` and `CommunicationObject` classes. A `CommunicationDomain` specifies possible [data hazards](https://en.wikipedia.org/wiki/Data_dependency),
e.g., read-after-write, write-after-write, etc. For example, you can add socket communication dependencies to a task by associating
an IP address with a communication domain, and ports with comunication channels within that domain:

    socket_domain = CommunicationDomain(rar=True, raw=True, war=True, waw=True)
    socket_object = CommunicationObject(socket_domain, ip_addr)
    socket_read = batch.read(socket_object, port_1)
    socket_write = batch.write(socket_object, port_2)
    task = batch.function(my_func, args, reads=[socket_read], writes=[socket_write])
-->

### Distributed Dictionary

The Distributed Dictionary service provides a scalable, in-memory distributed key-value store with semantics that are generally
similar to a standard Python dictionary. The Distrbuted Dictionary uses shared memory and RDMA to handle communication of keys
and values, and avoids central coordination so there are no bottle-necks to scaling. Revisiting an example above for the Batch
service, we will replace the file system as a means of inter-task communication with a Distributed Dictionary. The only part that
needs to be updated is the creation of subtasks for the compiled task--everything from the `Batch.compile` call and down is the same.

    # Generate the powers of a matrix and write them to a distributed dictionary
    from alamo import Batch, DDict
    import numpy as np

    # The Distributed Dictionary service will be used for communication of results
    batch = Batch()
    ddict = DDict()

    # Knowledge of reads and writes to the Distributed Dictionary will also be used by
    # the Batch service to determine data dependencies and how to parallelize tasks
    reads = lambda i: batch.read(ddict, i)
    writes = lambda i: batch.write(ddict, i + 1)

    a = np.array([i for i in range(100)])
    m = np.vander(a)

    # batch.function will create a task with specified arguments and reads/writes to the
    # distributed dictionary
    get_task = lambda i: batch.function(gpu_matmul_func, (m, ddict, i), reads(i), writes(i))

The code for `gpu_matmul_func` might look something like this.

    def gpu_matmul_func(original_matrix: np.ndarray, ddict: DDict, i: int):
        # read the current matrix stored in the Distributed Dictionary at key=i
        current_matrix = ddict[i]

        # actual matrix multiplication happens here
        next_matrix = do_dgemm(original_matrix, current_matrix)

        # write the next power of the matrix to the Distributed Dictionary at key=i+1
        ddict[i + 1] = new_matrix

The Distributed Dictionary provides synchronization mechanisms to make it possible for separate clients of the dictionary
to effectively cooperate when reading and writing data. For example, a `wait_for_keys` flag can be set when creating a
Distributed Dictionary, which allows readers of a specific key to block until another client writes a value for that key.
The Distributed Dictionary also makes it easy to co-locate compute with data, reducing the amount of network traffic required
to access your data.

### Queue

The Queue service provides a distributed queue interface that's similar to Python's multiprocessing.Queue, but can be accessed
anywhere in your deployment. Queues are easy to use with a simple put/get interface, and blazing performance through shared-memory
and a high bandwidth, low latency RDMA network. Unlike the Distributed Dictionary, Queues are not intended to be fault-tolerant, so
the Distributed Dictionary will be the right choice for applications requiring resiliency.

### Multiple Clients

<!-- dbg does a Dragon runtime/deployment have it's own allocation of network/storage? how are these partitioned? -->
Instances of the Batch, Distrbuted Dictionary, and Queue services are all represented by Python objects. All services allow for
multiple clients, i.e., a `Batch` object can be passed over a Queue, Distributed Dictionary, or other communication mechanism
to separate Python processes, and used simultaneously by all processes that have a copy of the object. Each client of an instance
of the Batch service can submit tasks independently to it, and tasks will be processed on a "first come, first serve" basis. Each
instance of the Batch service is allocated its own share of the compute and network resources, and all clients of the Batch instance
share the same set of resources.

## Limitations

### Fault-tolerance and Elasticity

In the future, the Batch service will be both fault-tolerant and elastic, i.e., the available resources for compute will expand
as necessary based on the load and specified user requirements.

## Further Information

All cloud services are based on the [Dragon distributed runtime](dragonhpc.org). Check out the link for examples and documentation for
the Dragon runtime.

<a id="alamo.batch.batch.Task"></a>

# The Batch Service API

## Task Objects

```python
class Task()
```

<a id="alamo.batch.batch.Task.__init__"></a>

#### \_\_init\_\_

```python
def __init__(batch,
             callback_func: Optional[Callable] = None,
             callback_args: tuple = (),
             reads: Optional[list] = None,
             writes: Optional[list] = None,
             compiled: bool = False) -> None
```

Initializes a new task.

**Arguments**:

- `batch`: The batch to which this task belongs.
- `callback_func`: A callback function to be run after this task completes. Defaults to None.
- `callback_args`: The arguments for this task's callback function. Defaults to ().

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Task.read"></a>

#### read

```python
def read(obj, *channels) -> None
```

Indicates READ accesses of a specified set of channels on a communication object, and

associates these accesses with this task. Associating READ accesses with a task allows
the Batch service to infer dependencies between subtasks in a compiled task, but has
no effect on individual (non-compiled) tasks.

**Arguments**:

- `obj`: The communication object being accessed.
- `*channels`: A tuple of channels on the communcation object that will be read from.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Task.write"></a>

#### write

```python
def write(obj, *channels) -> None
```

Indicates WRITE accesses of a specified set of channels on a communication object, and

associates these accesses with this task. Associating WRITE accesses with a task allows
the Batch service to infer dependencies between subtasks in a compiled task, but has
no effect on individual (non-compiled) tasks.

**Arguments**:

- `obj`: The communication object being accessed.
- `*channels`: A tuple of channels on the communcation object that will be written to.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Task.start"></a>

#### start

```python
def start() -> None
```

Start this task by sending its work chunks to the managers. Currently, a task can only

be started once and cannot be restarted after it completes.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Task.wait"></a>

#### wait

```python
def wait(timeout: float = default_timeout) -> None
```

Wait for this Task to complete. This can only be called after ``start`` has been called.

This function does not return the task's result; instead, use ``get`` for that purpose.

**Arguments**:

- `timeout`: The timeout for waiting. Defaults to 1e9.

**Raises**:

- `TimeoutError`: If the specified timeout is exceeded.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Task.run"></a>

#### run

```python
def run(timeout: float = default_timeout) -> Any
```

Starts a task and waits for it to complete. Currently, a task can only

be started once and cannot be restarted after it completes.

**Arguments**:

- `timeout` (`float`): The timeout for waiting. Defaults to 1e9.

**Raises**:

- `TimeoutError`: If the specified timeout is exceeded.
- `Exception`: If this Task raised an exception while running. The exception raised by the
task is propagated back to the host that started the task so it can be raised here.

**Returns**:

`Any`: Returns the result of the operation being waited on.

<a id="alamo.batch.batch.Task.uid"></a>

#### uid

```python
@property
def uid()
```

Provides the unique ID for this task.

<a id="alamo.batch.batch.Task.result"></a>

#### result

```python
@property
def result()
```

Handle for the task's result. This should not be accessed until the task completes. The
handle has type AsyncDict.

<a id="alamo.batch.batch.Task.stdout"></a>

#### stdout

```python
@property
def stdout()
```

Handle for the task's stdout. This should not be accessed until the task completes. The
handle has type AsyncDict.

<a id="alamo.batch.batch.Task.stderr"></a>

#### stderr

```python
@property
def stderr()
```

Handle for the task's stderr. This should not be accessed until the task completes. The
handle has type AsyncDict.

<a id="alamo.batch.batch.Task.dump_dag"></a>

#### dump\_dag

```python
def dump_dag(file_name: str) -> None
```

Dump a PNG image of the dependency DAG associated with a compiled program.

**Arguments**:

- `file_name`: Name for the new PNG file.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.AsyncDict"></a>

## AsyncDict Objects

```python
class AsyncDict()
```

<a id="alamo.batch.batch.AsyncDict.get"></a>

#### get

```python
def get(tuid: Optional[int] = None, timeout: Optional[float] = None) -> Any
```

Get the result, stdout, or stderr for a task. For individually started tasks,

subtasks of compiled tasks, and compiled tasks with a single subtask, no argument
is required for the task UID. However, compiled tasks with more than one subtask
must specify the UID of the desired subtask.

**Arguments**:

- `tuid`: The unique ID of the desired task.
- `timeout`: A timeout for waiting on the task to complete.

**Returns**:

`Any`: Returns the output for a specific task. The output can be the result returned
from the task, or its stdout or stderr.

<a id="alamo.batch.batch.Batch"></a>

## Batch Objects

```python
class Batch()
```

<a id="alamo.batch.batch.Batch.__init__"></a>

#### \_\_init\_\_

```python
def __init__(num_workers: int = cpu_count(),
             log_level=logging.WARNING,
             enable_telem: Optional[bool] = False) -> None
```

Initializes a batch.

**Arguments**:

- `num_workers` (`int`): Number of workers for this batch. Defaults to multiprocessing.cpu_count().
- `log_level`: The logging level to use for this Batch instance. Defaults to logging.WARNING.
- `enable_telem` (`bool`): Indicates if telemetry should be enabled for this Batch instance. Defaults to False.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.__del__"></a>

#### \_\_del\_\_

```python
def __del__() -> None
```

Non-primary clients must close the batch if they haven't already done so.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.__setstate__"></a>

#### \_\_setstate\_\_

```python
def __setstate__(state) -> None
```

Set state for a new client, including registering the client with the managers.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.read"></a>

#### read

```python
def read(obj, *channels) -> DataAccess
```

Indicates READ accesses of a specified set of channels on a communication object. These

accesses are not yet associated with a given task.

**Arguments**:

- `obj`: The communication object being accessed.
- `*channels`: A tuple of channels on the communcation object that will be read from.

**Returns**:

`DataAccess`: Returns an descriptor for the data access that can be passed to (in a list) when creating a new task.

<a id="alamo.batch.batch.Batch.write"></a>

#### write

```python
def write(obj, *channels) -> DataAccess
```

Indicates WRITE accesses of a specified set of channels on a communication object. These

accesses are not yet associated with a given task.

**Arguments**:

- `obj`: The communication object being accessed.
- `*channels`: A tuple of channels on the communcation object that will be writtent o.

**Returns**:

`DataAccess`: Returns an descriptor for the data access that can be passed to (in a list) when creating a new task.

<a id="alamo.batch.batch.Batch.close"></a>

#### close

```python
def close() -> None
```

Indicates to the Batch service that no more work will be submitted to it. All clients

must call this function, although it will be called by the ``__del__`` method of Batch
if not called by the user. This should only be called once per client.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.join"></a>

#### join

```python
def join(timeout: float = default_timeout) -> None
```

Wait for the completion of a Batch instance. This function will block until all work

submitted to the Batch service by all clients is complete, and all clients have called
``close``. Only the primary client (i.e., the one that initially created this Batch
instance) should call ``join``, and it should be called after ``close``. This should
only be called once by the primary client.

**Arguments**:

- `float`: A timeout value for waiting on batch completion. Defaults to 1e9.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.terminate"></a>

#### terminate

```python
def terminate() -> None
```

Force the termination of a Batch instance. This should only be called by the primary

client (i.e., the one that initially created this Batch instance), and it should only
be called once. This will be called when the primary Batch object is garbage collected
if the user has not called ``join`` or ``terminate``.

**Returns**:

`None`: Returns None.

<a id="alamo.batch.batch.Batch.function"></a>

#### function

```python
def function(func: Callable,
             *args,
             callback_func: Optional[Callable] = None,
             callback_args: tuple = (),
             reads: Optional[list] = None,
             writes: Optional[list] = None) -> _Function
```

Creates a new function task.

**Arguments**:

- `func`: The function to associate with the object.
- `*args`: The arguments for the function.
- `callback_func`: A callback function to be run after this function task completes. The first
argument to the callback is the result of the task; the tuple of user-supplied arguments are the rest.
The callback function only runs if the task is successful. Defaults to None.
- `callback_args`: The arguments for this function task's callback function. Defaults to ().

**Returns**:

`Function`: The new function task.

<a id="alamo.batch.batch.Batch.process"></a>

#### process

```python
def process(args,
            bufsize=-1,
            executable=None,
            stdin=None,
            stdout=None,
            stderr=None,
            preexec_fn=None,
            close_fds=True,
            shell=False,
            cwd=None,
            env=None,
            universal_newlines=None,
            startupinfo=None,
            creationflags=0,
            restore_signals=True,
            start_new_session=False,
            pass_fds=(),
            group=None,
            extra_groups=None,
            user=None,
            umask=-1,
            encoding=None,
            errors=None,
            text=None,
            pipesize=-1,
            process_group=None,
            callback_func: Optional[Callable] = None,
            callback_args: tuple = (),
            reads: Optional[list] = None,
            writes: Optional[list] = None) -> _Process
```

Creates a new process task. All arguments except for ``batch``, ``callback_func``, and ``callback_args``

are based on the arguments to Python's ``subprocess.Popen`` function. See documentation for ``Popen``
for further information on its arguments.

**Arguments**:

- `callback_func`: A callback function to be run after this function task completes. The first
argument to the callback is the result of the task; the tuple of user-supplied arguments are the rest.
The callback function only runs if the task is successful. Defaults to None.
- `callback_args`: The arguments for this function task's callback function. Defaults to ().

**Returns**:

`Process`: The new process task.

<a id="alamo.batch.batch.Batch.job"></a>

#### job

```python
def job(target,
        args=(),
        num_procs: int = 1,
        cwd: str = None,
        env: dict = None,
        policy: Policy = None,
        callback_func: Optional[Callable] = None,
        callback_args=(),
        reads: Optional[list] = None,
        writes: Optional[list] = None) -> _Job
```

Creates a new job task. All arguments except for ``batch``, ``callback_func``, and ``callback_args`` are

based on the arguments to Dragon's ``ProcessTemplate``.

**Arguments**:

- `target` (`str or callable`): The binary or Python callable to execute.
- `args` (`tuple, optional`): The arguments to pass to the binary or callable. Defaults to None.
- `cwd` (`str, optional`): The current working directory. Defaults to None.
- `env` (`dict, optional`): The environment variables to pass to the process environment. Defaults to None
- `policy` (`dragon.infrastructure.policy.Policy, optional`): Determines the placement and resources of the process.
- `callback_func`: A callback function to be run after this function task completes. The first
argument to the callback is the result of the task; the tuple of user-supplied arguments are the rest.
The callback function only runs if the task is successful. Defaults to None.
- `callback_args`: The arguments for this function task's callback function. Defaults to ().

**Returns**:

`Job`: The new job task.

<a id="alamo.batch.batch.Batch.compile"></a>

#### compile

```python
def compile(
    tasks_to_compile: list[Task],
    callback_func: Optional[Callable] = None,
    callback_args: tuple = ()) -> Task
```

Generate a single, compiled task from a list of tasks. After a list of tasks has been

compiled, the individual subtasks of the compiled task can no longer be started or waited
on separately--``start``, ``wait``, and ``run`` should all be called via the compiled task.

**Arguments**:

- `tasks_to_compile` (`list`): List of tasks to compile.
- `callback_func` (`Callable, optional`): A callback function for the compiled task. This callback runs after all the
callback functions for subtasks complete. Unlike callbacks for individual tasks, there is no result
from the compiled task to be passed as an argument; the only arguments to this callback are supplied
by the user via ``callback_args``.
- `callback_args` (`tuple, optional`): Callback arguments for the compiled task.

**Raises**:

- `RuntimeError`: If there is an issue while setting up the dependency graph

**Returns**:

`Task`: The compiled task.

