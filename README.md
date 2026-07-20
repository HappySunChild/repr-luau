# repr-luau
An implementation of [Python's builtin `repr`](https://docs.python.org/3/library/functions.html#repr) function in Luau.

## Example Usage
```luau
const repr = require("repr")

print(repr({ name = "john doe", age = 20 }, { pretty_tables = false })) --> { age = 20, name = "john doe" }
```