type ReprOptions = {
	pretty_tables: boolean?,
	show_function_debug_names: boolean?,
	show_buffer_bytes: boolean?,
}

const DEFAULT_OPTIONS: ReprOptions = {
	pretty_tables = true,
	show_function_debug_names = false,
	show_buffer_bytes = false,
}

type RenderedPair = { key: string, value: string }

const function render_table(rendered_pairs: { RenderedPair }, indent: number, pretty: boolean): string
	if #rendered_pairs == 0 then
		return "{}"
	end

	if pretty then
		const outer_indent = string.rep("\t", indent)
		const inner_indent = string.rep("\t", indent + 1)
		const lines = { "{" }

		for _, pair in rendered_pairs do
			table.insert(lines, `{inner_indent}{pair.key} = {pair.value},`)
		end

		table.insert(lines, `{outer_indent}}`)

		return table.concat(lines, "\n")
	else
		const fields = {}

		for _, pair in rendered_pairs do
			table.insert(fields, `{pair.key} = {pair.value}`)
		end

		return `\{ {table.concat(fields, ", ")} }`
	end
end

const function sort_pairs(a: RenderedPair, b: RenderedPair)
	return a.key < b.key
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
	if type(v) ~= "string" then
		return false
	end

	if string.len(v) == 0 then
		return false
	end

	if string.match(v, "^[%a_][%w_]*$") == nil then
		return false
	end

	if LUAU_KEYWORDS[v] ~= nil then
		return false
	end

	return true
end

const function repr_primitive(x: any, options: ReprOptions)
	const x_type = type(x)

	if x_type == "nil" then
		return "nil"
	elseif x_type == "string" then
		return string.format("%q", x)
	elseif x_type == "boolean" then
		return tostring(x)
	elseif x_type == "number" then
		if x == math.huge then
			return "math.huge"
		elseif x == -math.huge then
			return "-math.huge"
		elseif x ~= x then
			return "math.nan"
		end

		return tostring(x)
	elseif x_type == "integer" then
		return `{x}i`
	elseif x_type == "vector" then
		return `vector.create({repr_primitive(x.x, options)}, {repr_primitive(x.y, options)}, {repr_primitive(
			x.z,
			options
		)})`
	elseif x_type == "buffer" then
		const show_bytes = options.show_buffer_bytes
		const len = buffer.len(x)

		if show_bytes then
			const escapes = table.create(len)

			for index = 1, len do
				escapes[index] = string.format("\\x%02X", buffer.readu8(x, index - 1))
			end

			const buffer_string = table.concat(escapes, "")

			return `buffer.fromstring("{buffer_string}")`
		else
			return `buffer.create({len})`
		end
	elseif x_type == "function" then
		const show_debug_name = options.show_function_debug_names

		const arg_count: number, is_variadic: boolean, name: string? = debug.info(x :: () -> (), "an")
		const arg_list: { string } = {}

		for i = 1, arg_count do
			table.insert(arg_list, `a{i}`)
		end

		if is_variadic then
			table.insert(arg_list, "...")
		end

		const display_args = table.concat(arg_list, ", ")

		return `function {if show_debug_name and is_luau_identifier(name) then name else ""}({display_args}) ... end`
	end

	return `<{x}>`
end

const function repr_table(current: { [any]: any }, seen: { [any]: number }, depth: number, options: ReprOptions): string
	if seen[current] ~= nil then
		return "{ RECURSIVE }"
	end

	depth += 1
	seen[current] = depth

	const rendered_pairs = {}

	for key, value in current do
		const field_key = if is_luau_identifier(key)
			then tostring(key)
			else `[{(if type(key) == "table"
				then repr_table(key, seen, depth, options)
				else repr_primitive(key, options))}]`
		const field_value = if type(value) == "table"
			then repr_table(value, seen, depth, options)
			else repr_primitive(value, options)

		table.insert(rendered_pairs, {
			key = field_key,
			value = field_value,
		})
	end

	table.sort(rendered_pairs, sort_pairs)

	depth -= 1

	local output = render_table(rendered_pairs, depth, options.pretty_tables)
	const metatable = getmetatable(current) :: any?

	if type(metatable) == "table" then
		output = `setmetatable({output}, {repr_table(metatable, seen, depth, options)})`
	end

	if table.isfrozen(current) then
		output = `table.freeze({output})`
	end

	seen[current] = nil

	return output
end

const function repr(x: any, options: ReprOptions?): string
	const x_type = type(x)

	options = options or DEFAULT_OPTIONS

	if x_type == "table" then
		const seen = {}

		return repr_table(x, seen, 0, options)
	end

	return repr_primitive(x, options)
end

return repr
