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

const LUAU_KEYWORD = {
	-- ["const"] = true, -- const technically isn't a keyword
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

	if string.match(v, "^[%a_][%w_]*") == nil then
		return false
	end

	if LUAU_KEYWORD[v] ~= nil then
		return false
	end

	return true
end

const function repr(x: any, options: ReprOptions?)
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
		return `vector.create({repr(x.x)}, {repr(x.y)}, {repr(x.z)})`
	elseif x_type == "buffer" then
		const show_bytes = (options or DEFAULT_OPTIONS).show_buffer_bytes
		const len = buffer.len(x)

		if show_bytes then
			const raw_bytes = buffer.tostring(x)
			const escapes = table.create(len)

			for index = 1, len do
				escapes[index] = string.format("\\x%X", string.byte(raw_bytes, index, index))
			end

			const buffer_string = table.concat(escapes, "")

			return `buffer.fromstring("{buffer_string}")`
		else
			return `buffer.create({len})`
		end
	elseif x_type == "function" then
		const use_debug_name = (options or DEFAULT_OPTIONS).show_function_debug_names

		const arg_count: number, is_variadic: boolean, name: string? = debug.info(x :: () -> (), "an")
		const arg_list: { string } = {}

		for i = 1, arg_count do
			table.insert(arg_list, `a{i}`)
		end

		if is_variadic then
			table.insert(arg_list, "...")
		end

		const display_args = table.concat(arg_list, ", ")

		return `function {if use_debug_name then name or "" else ""}({display_args}) end`
	elseif x_type == "table" then
		const format_tables = (options or DEFAULT_OPTIONS).pretty_tables

		const active: { [any]: number } = {}
		local depth = 0

		const function process(current: any)
			if type(current) ~= "table" then
				return repr(current)
			end

			if active[current] ~= nil then
				return `\{ RECURSIVE +{depth - active[current] - 1} }`
			end

			active[current] = depth

			depth += 1

			const rendered_pairs = {}

			for key, value in current do
				table.insert(rendered_pairs, {
					key = if is_luau_identifier(key) then tostring(key) else `[{process(key)}]`,
					value = process(value),
				})
			end

			depth -= 1

			table.sort(rendered_pairs, sort_pairs)

			local output = render_table(rendered_pairs, depth, format_tables)
			const metatable = getmetatable(current) :: any?

			if type(metatable) == "table" then
				output = `setmetatable({output}, {process(metatable)})`
			end

			if table.isfrozen(current) then
				output = `table.freeze({output})`
			end

			return output
		end

		return process(x)
	end

	return `<{x}>`
end

return repr
