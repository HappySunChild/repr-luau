export type ReprOptions = {
	pretty_tables: boolean?,
	show_function_debug_names: boolean?,
	show_function_bodies: boolean?,
	show_buffer_bytes: boolean?,
	show_explicit_array_keys: boolean?,
	convert_numerical_language_constants: boolean?,
	max_table_depth: number?,

	custom_formatters: { [string]: ReprFormatter }?,
}
export type ReprContext = ReprOptions & {
	repr: (v: any) -> string,
	table_showing: { [any]: number },
	table_depth: number,
}
export type ReprFormatter = (v: any, context: ReprContext) -> string

const DEFAULT_OPTIONS: ReprOptions = {
	pretty_tables = true,
	show_function_debug_names = false,

	show_function_bodies = true,
	show_buffer_bytes = true,
	show_explicit_array_keys = false,
	convert_numerical_language_constants = true,
	max_table_depth = 20,
}

const function merge_tables(base: any, other: any): any
	const merged = table.clone(base)

	for key, other_value in other do
		if merged[key] == nil then
			merged[key] = other_value
			continue
		end

		const existing_value = merged[key]

		if type(existing_value) == "table" and type(other_value) == "table" then
			merged[key] = merge_tables(existing_value, other_value)
		end
	end

	return merged
end

const function render_table(record_part: { string }, array_part: { string }, indent: number, pretty: boolean?): string
	if #record_part + #array_part == 0 then
		return "{}"
	end

	if pretty then
		const outer_indent = string.rep("\t", indent)
		const inner_indent = string.rep("\t", indent + 1)
		const lines = { "{" }

		for _, value in array_part do
			table.insert(lines, `{inner_indent}{value},`)
		end

		for _, pair in record_part do
			table.insert(lines, `{inner_indent}{pair},`)
		end

		table.insert(lines, `{outer_indent}}`)

		return table.concat(lines, "\n")
	end

	const fields = table.create(#record_part + #array_part)

	for _, value in array_part do
		table.insert(fields, value)
	end

	for _, pair in record_part do
		table.insert(fields, pair)
	end

	return `\{ {table.concat(fields, ", ")} }`
end

const ESCAPE_SEQUENCES: { [string]: string } = {
	["\\"] = "\\\\",
	["\n"] = "\\n",
	["\t"] = "\\t",
	["\r"] = "\\r",
	["\v"] = "\\v",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\a"] = "\\a",
}

for byte = 1, 31 do
	const char = string.char(byte)

	if ESCAPE_SEQUENCES[char] then
		continue
	end

	ESCAPE_SEQUENCES[char] = `\\{byte}`
end

const LUAU_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["continue"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["while"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
}

const function is_luau_identifier(v: any): boolean
	return type(v) == "string" and string.match(v, "^[%a_][%w_]*$") ~= nil and not LUAU_KEYWORDS[v]
end

const DEFAULT_FORMATTERS: { [string]: ReprFormatter } = {
	["nil"] = function(): string
		return "nil"
	end,
	string = function(v: string): string
		const escaped = string.gsub(v, ".", ESCAPE_SEQUENCES)

		const contains_quotes = string.find(escaped, '"') ~= nil
		const contains_apostrophe = string.find(escaped, "'") ~= nil

		if contains_quotes then
			if contains_apostrophe then
				return `"{string.gsub(escaped, '"', '\\"')}"`
			end

			return `'{escaped}'`
		end

		return `"{escaped}"`
	end,
	boolean = function(v: boolean): string
		return tostring(v)
	end,
	number = function(v: number, context): string
		if context.convert_numerical_language_constants then
			if v == math.huge then
				return "math.huge"
			elseif v == -math.huge then
				return "-math.huge"
			elseif v ~= v then
				return "math.nan"
			end
		end

		return tostring(v)
	end,
	integer = function(v: integer): string
		return `{v}i`
	end,
	vector = function(v: vector, context): string
		const repr = context.repr
		return `vector.create({repr(v.x)}, {repr(v.y)}, {repr(v.z)})`
	end,
	buffer = function(v: buffer, context): string
		const len = buffer.len(v)

		if context.show_buffer_bytes then
			const escapes = table.create(len)

			for index = 1, len do
				escapes[index] = string.format("\\x%02X", buffer.readu8(v, index - 1))
			end

			const buffer_string = table.concat(escapes, "")

			return `buffer.fromstring("{buffer_string}")`
		else
			return `buffer.create({len})`
		end
	end,
	["function"] = function(v: (...any) -> ...any, context): string
		const show_debug_name = context.show_function_debug_names
		const show_body = context.show_function_bodies

		const arg_count: number, is_variadic: boolean, debug_name: string? = debug.info(v :: () -> (), "an")
		const arg_list: { string } = {}

		for i = 1, arg_count do
			table.insert(arg_list, `a{i}`)
		end

		if is_variadic then
			table.insert(arg_list, "...")
		end

		const display_args = table.concat(arg_list, ", ")
		const display_name = if show_debug_name and is_luau_identifier(debug_name) then debug_name else ""
		const display_body = if show_body then " end" else ""

		return `function {display_name}({display_args}){display_body}`
	end,
	table = function(v: { [any]: any }, context): string
		const current_depth = context.table_depth
		const showing = context.table_showing

		if context.max_table_depth ~= nil and current_depth >= context.max_table_depth then
			return "{ ... }"
		end

		if showing[v] ~= nil then
			return `\{ RECURSIVE +{current_depth - showing[v]} }`
		end

		const show_array_keys = context.show_explicit_array_keys

		showing[v] = current_depth

		context.table_depth += 1

		const record_part: { string } = {}
		const array_part: { string } = {}

		const array_len = #v

		const repr = context.repr

		for key: any, value: any in v do
			const field_value = repr(value)

			if
				not show_array_keys
				and type(key) == "number"
				and math.floor(key) == key
				and key > 0
				and key <= array_len
			then
				table.insert(array_part, field_value)
				continue
			end

			const field_key = if is_luau_identifier(key) then tostring(key) else `[{(repr(key))}]`

			table.insert(record_part, `{field_key} = {field_value}`)
		end

		table.sort(record_part)

		local output = render_table(record_part, array_part, current_depth, context.pretty_tables)
		const metatable = getmetatable(v) :: any?

		context.table_depth -= 1

		if type(metatable) == "table" then
			output = `setmetatable({output}, {repr(metatable)})`
		end

		if table.isfrozen(v) then
			output = `table.freeze({output})`
		end

		showing[v] = nil

		return output
	end,
}

const function recursive_repr(v: any, context: ReprContext): string
	const v_type = typeof(v)
	const formatter = context.custom_formatters ~= nil and context.custom_formatters[v_type]
		or DEFAULT_FORMATTERS[v_type]

	if formatter ~= nil then
		return formatter(v, context)
	end

	return `<{v_type}: {v}>`
end

const function repr(v: any, options: ReprOptions?): string
	const context: ReprContext = if options == nil
		then DEFAULT_OPTIONS :: any
		else merge_tables(options, DEFAULT_OPTIONS)
	context.table_showing = {}
	context.table_depth = 0
	context.repr = function(v: any): string
		return recursive_repr(v, context)
	end

	return recursive_repr(v, context)
end

return repr
