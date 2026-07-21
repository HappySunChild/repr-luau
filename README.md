# repr-luau
A Luau implementation of [Python's builtin `repr`](https://docs.python.org/3/library/functions.html#repr).

The output of this `repr` implementation is not intended to be converted back into the original value (as that's not technically possible currently).
Instead this implementation is largely meant for displaying debug information easily (e.g. in a REPL or debug HUD).


## Example Usage
```luau
const repr = require("repr")

const value = {
	name = "John Doe",
	age = 20,
	scores = { 10, 15, 30 },
}

print(repr(value))
```

Output:

```text
{
	age = 20,
	name = "John Doe",
	scores = {
		10,
		15,
		30,
	},
}
```

### Recursive Tables
To prevent infinite loops from occurring, this implementation detects recursive tables and replaces them with `"{ RECURSIVE +N }"`.
The `N` indicates how many parent levels up the referenced table appears, so for example `{ a = { RECURSIVE +1 } }` would mean that `a` points to the table that contains it which would look something like this in Luau:
```luau
local t = {}
t.a = t
```

## Options
This implementation also provides a way to easily configure the output, like whether tables are pretty formatted. Here's a full list of options that are currently provided:

| Option                                 | Type      | Default | Description                                                                       |
| -------------------------------------- | --------- | ------- | --------------------------------------------------------------------------------- |
| `pretty_tables`                        | `boolean` | `true`  | Whether to pretty-print tables with indentation, newlines, etc.                   |
| `show_function_debug_names`            | `boolean` | `false` | Whether function debug names are used.                                            |
| `show_function_bodies`                 | `boolean` | `true`  | Whether empty function bodies are included.                                       |
| `show_buffer_bytes`                    | `boolean` | `true`  | Whether buffers are displayed using their raw hex bytes.                          |
| `show_explicit_array_keys`             | `boolean` | `false` | Whether the numerical keys for the array part of a table are explicitly shown.    |
| `convert_numerical_language_constants` | `boolean` | `true`  | Whether numerical language constants such as `math.huge` and `math.nan` are used. |
| `max_table_depth`                      | `number`  | `20`    | Maximum table nesting depth to display.                                           |
