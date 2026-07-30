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
The `N` indicates how many parent levels up the referenced table appears. For example, `{ a = { RECURSIVE +1 } }` would mean that `a` points to the table it is contained within, which in Luau would look something like this:
```luau
local t = {}
t.a = t
```
Recursive metatables are also detected, and are shown as `{ RECURSIVE +0 }`.
```luau
local t = {}
setmetatable(t, t)
```

Output:

```text
setmetatable({}, { RECURSIVE +0 })
```

## Options
This implementation also provides a way to easily configure the output. Here's a full list of options that are currently provided:

| Option                                 | Type      | Default | Description                                                                       | Example Output                                   |
| -------------------------------------- | --------- | ------- | --------------------------------------------------------------------------------- | ------------------------------------------------ |
| `pretty_tables`                        | `boolean` | `true`  | Whether to pretty-print tables with indentation, newlines, etc.                   | [example](#pretty_tables)                        |
| `show_function_debug_names`            | `boolean` | `false` | Whether function debug names are used.                                            | [example](#show_function_debug_names)            |
| `show_function_bodies`                 | `boolean` | `true`  | Whether empty function bodies are included.                                       | [example](#show_function_bodies)                 |
| `show_buffer_bytes`                    | `boolean` | `true`  | Whether buffers are displayed using their raw hex bytes.                          | [example](#show_buffer_bytes)                    |
| `show_explicit_array_keys`             | `boolean` | `false` | Whether the numerical keys for the array part of a table are explicitly shown.    | [example](#show_explicit_array_keys)             |
| `convert_numerical_language_constants` | `boolean` | `true`  | Whether numerical language constants such as `math.huge` and `math.nan` are used. | [example](#convert_numerical_language_constants) |
| `max_table_depth`                      | `number`  | `20`    | Maximum table nesting depth to display.                                           | [example](#max_table_depth)                      |

---
### Option Output Examples

#### `pretty_tables`
**true**
```text
{
	a = "hello"
	b = 100,
	c = {
		123,
		"world"
	}
}
```
**false**
```text
{ a = "hello", b = 100, c = { 123, "world } }
```

#### `show_function_debug_names`
**true**
```text
function hello() end
```
**false**
```text
function () end
```

#### `show_function_bodies`
**true**
```text
function () end
```
**false**
```text
function ()
```

#### `show_buffer_bytes`
**true**
```text
buffer.fromstring("\x68\x65\x6C\x6C\x6F\x77\x6F\x72\x6C\x64")
```
**false**
```text
buffer.create(10)
```

#### `show_explicit_array_keys`
**true**
```text
{
	[1] = "hello",
	[2] = "world,
	[3] = {
		[1] = true,
		[2] = false
	}
}
```
**false**
```text
{
	"hello",
	"world",
	{
		true,
		false,
	},
}
```

#### `convert_numerical_language_constants`
**true**
```text
math.huge
```
**false**
```text
inf
```

#### `max_table_depth`
**5**
```text
{
	a = 1,
	b = 2,
	c = {
		1,
		2,
		3,
	}
}
```
**1**
```text
{
	a = 1,
	b = 2,
	c = { ... },
}
```