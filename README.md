This is a (somewhat hacky) workaround for some limitations with Mathematica 12.0's
Python Sessions, i.e. functionality associated with `StartExternalSession[]`,
`ExternalEvaluate[]`, etc.

# The Issue

Mathematica serializes all data and thus does not allow dynamic passing around of
stateful objects such as references to class instances:

![Limits of Mathematica 12 Python bridge](/docs/docs1.png)

# The Solution

With this extension, stateful objects are abstracted inside `PyHandle` objects:

![Usage of the Py extension](/docs/docs2.png)

# The New Issue: Deallocation

This extension does not track memory allocations, so objects that are not explicitly
freed will get leaked.

This is usually not a problem for small experimental settings inside a notebook.

![Explicit Deallocation](/docs/docs3.png)

# One Solution: PyScoped

As long as you are able to separate concerns of allocation, ´PyScoped` can help:

![Usage of PyScoped](/docs/docs4.png)

# Limitations

Many. For example, returned values may be either an object instance or primitive.
However, objects inside containers like lists are not supported. The same is true
for arguments passed to Python methods.

