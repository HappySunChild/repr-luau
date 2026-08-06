export type ReprOptions = {
	pretty_tables: boolean?,
	show_function_debug_names: boolean?,
	show_function_bodies: boolean?,
	show_buffer_bytes: boolean?,
	show_explicit_array_keys: boolean?,
	convert_numerical_language_constants: boolean?,
	max_table_depth: number?,

	show_instance_full_names: boolean?,
	show_color3_as_decimals: boolean?,
}
type ReprFormatter = (v: any, context: ReprContext, repr: (v: any) -> string) -> string

type ReprContext = {
	table_showing: { [any]: number },
	table_depth: number,
	options: ReprOptions,
}

const DEFAULT_OPTIONS: ReprOptions = {
	pretty_tables = true,
	show_function_debug_names = false,

	show_function_bodies = true,
	show_buffer_bytes = true,
	show_explicit_array_keys = false,
	convert_numerical_language_constants = true,
	max_table_depth = 20,

	show_instance_full_names = true,
	show_color3_as_decimals = false,
}

const function merge_tables(tab_a: any, tab_b: any): any
	const merged = table.clone(tab_a)

	for key, value in tab_b do
		if merged[key] == nil then
			merged[key] = value
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
	number = function(v: number, context: ReprContext): string
		if context.options.convert_numerical_language_constants then
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
	integer = function(v: integer, context: ReprContext): string
		return `{v}i`
	end,
	vector = function(v: vector, context: ReprContext, repr: (any) -> string): string
		return `vector.create({repr(v.x)}, {repr(v.y)}, {repr(v.z)})`
	end,
	buffer = function(v: buffer, context: ReprContext): string
		const len = buffer.len(v)

		if context.options.show_buffer_bytes then
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
	["function"] = function(v: () -> (), context: ReprContext): string
		const show_debug_name = context.options.show_function_debug_names
		const show_body = context.options.show_function_bodies

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
	table = function(v: { [any]: any }, context: ReprContext, repr: (any) -> string): string
		const options = context.options
		const depth = context.table_depth
		const showing = context.table_showing

		if options.max_table_depth ~= nil and depth >= options.max_table_depth then
			return "{ ... }"
		end

		if showing[v] ~= nil then
			return `\{ RECURSIVE +{depth - showing[v]} }`
		end

		const show_array_keys = options.show_explicit_array_keys

		showing[v] = depth

		context.table_depth += 1

		const record_part: { string } = {}
		const array_part: { string } = {}

		const array_len = #v

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

		local output = render_table(record_part, array_part, depth, options.pretty_tables)
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

	Axes = function(v: Axes, _, repr: (any) -> string): string
		const args = {}

		if v.X then
			table.insert(args, repr(Enum.Axis.X))
		end
		if v.Y then
			table.insert(args, repr(Enum.Axis.Y))
		end
		if v.Z then
			table.insert(args, repr(Enum.Axis.Z))
		end

		return `Axes.new({table.concat(args, ", ")})`
	end,
	BrickColor = function(v: BrickColor, _, repr: (any) -> string): string
		return `BrickColor.new({repr(v.Name)})`
	end,
	CFrame = function(v: CFrame): string
		return `CFrame.new({table.concat({ v:GetComponents() }, ", ")})`
	end,
	Color3 = function(v: Color3, context: ReprContext, repr: (any) -> string): string
		if context.options.show_color3_as_decimals then
			return `Color3.new({repr(v.R)}, {repr(v.G)}, {repr(v.B)})`
		end

		return string.format("Color3.fromRGB(%s, %s, %s)", repr(v.R * 255), repr(v.G * 255), repr(v.B * 255))
	end,
	ColorSequence = function(v: ColorSequence, _, repr: (any) -> string): string
		const keypoints = v.Keypoints

		if #keypoints > 2 then
			return `ColorSequence.new({repr(keypoints)})`
		end

		const first, second = keypoints[1], keypoints[2]

		if first.Value == second.Value then
			return `ColorSequence.new({repr(first.Value)})`
		end

		return `ColorSequence.new({repr(first.Value)}, {repr(second.Value)})`
	end,
	ColorSequenceKeypoint = function(v: ColorSequenceKeypoint, _, repr: (any) -> string): string
		return `ColorSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)})`
	end,
	Content = function(v: Content, _, repr: (any) -> string): string
		const source_type = v.SourceType

		if source_type == Enum.ContentSourceType.None then
			return "Content.none"
		elseif source_type == Enum.ContentSourceType.Object then
			return `Content.fromObject({repr(v.Object)})`
		elseif source_type == Enum.ContentSourceType.Uri then
			return `Content.fromUri({repr(v.Uri)})`
		end

		return `<Content {source_type.Name}>`
	end,
	DateTime = function(v: DateTime, _, repr: (any) -> string): string
		return `DateTime.fromUnixTimestamp({repr(v.UnixTimestamp)})`
	end,
	Enums = function(): string
		return "Enums"
	end,
	Enum = function(v: Enum): string
		return `Enums.{v}`
	end,
	EnumItem = function(v: EnumItem): string
		return `Enums.{v.EnumType}.{v.Name}`
	end,
	Faces = function(v: Faces, _, repr: (any) -> string): string
		const args = {}

		if v.Top then
			table.insert(args, repr(Enum.NormalId.Top))
		end

		if v.Bottom then
			table.insert(args, repr(Enum.NormalId.Bottom))
		end

		if v.Left then
			table.insert(args, repr(Enum.NormalId.Left))
		end

		if v.Right then
			table.insert(args, repr(Enum.NormalId.Right))
		end

		if v.Front then
			table.insert(args, repr(Enum.NormalId.Front))
		end

		if v.Back then
			table.insert(args, repr(Enum.NormalId.Back))
		end

		return `Faces.new({table.concat(args, ", ")})`
	end,
	Instance = function(v: Instance, context: ReprContext): string
		if not context.options.show_instance_full_names then
			return v.Name
		end

		const path = {}
		local current: Instance? = v

		while current ~= nil and current.Parent ~= nil do
			const name = current.Name
			const parent = current.Parent

			table.insert(
				path,
				1,
				if is_luau_identifier(name)
					then if parent == nil or parent == game then name else `.{name}`
					else `["{name}"]`
			)

			current = parent
		end

		return table.concat(path, "")
	end,
	NumberRange = function(v: NumberRange, _, repr: (any) -> string): string
		if v.Min == v.Max then
			return `NumberRange.new({repr(v.Min)})`
		end

		return `NumberRange.new({repr(v.Min)}, {repr(v.Max)})`
	end,
	NumberSequence = function(v: NumberSequence, _, repr: (any) -> string): string
		const keypoints = v.Keypoints

		if #keypoints > 2 then
			return `NumberSequence.new({repr(keypoints)})`
		end

		const first, second = keypoints[1], keypoints[2]

		if first.Value == second.Value then
			return `NumberSequence.new({repr(first.Value)})`
		end

		return `NumberSequence.new({repr(first.Value)}, {repr(second.Value)})`
	end,
	NumberSequenceKeypoint = function(v: NumberSequenceKeypoint, _, repr: (any) -> string): string
		const envelope = v.Envelope

		if envelope == 0 then
			return `NumberSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)})`
		end

		return `NumberSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)}, {repr(envelope)})`
	end,
	PathWaypoint = function(v: PathWaypoint, _, repr: (any) -> string): string
		return `PathWaypoint.new({repr(v.Position)}, {repr(v.Action)}, {repr(v.Label)})`
	end,
	PhysicalProperties = function(v: PhysicalProperties, _, repr: (any) -> string): string
		return string.format(
			"PhysicalProperties.new(%s, %s, %s, %s, %s, %s)",
			repr(v.Density),
			repr(v.Friction),
			repr(v.Elasticity),
			repr(v.FrictionWeight),
			repr(v.ElasticityWeight),
			repr(v.AcousticAbsorption)
		)
	end,
	Random = function(v: Random): string
		return "Random.new()"
	end,
	Ray = function(v: Ray, _, repr: (any) -> string): string
		return `Ray.new({repr(v.Origin)}, {repr(v.Direction)})`
	end,
	RaycastParams = function(v: RaycastParams, _, repr: (any) -> string): string
		return "RaycastParams.new()"
	end,
	Rect = function(v: Rect, _, repr: (any) -> string): string
		const min, max = v.Min, v.Max
		return `Rect.new({repr(min.X)}, {repr(min.Y)}, {repr(max.X)}, {repr(max.Y)})`
	end,
	Region3 = function(v: Region3, _, repr: (any) -> string): string
		const min = v.CFrame * (-v.Size / 2)
		const max = v.CFrame * (v.Size / 2)
		return `Region3.new({repr(min)}, {repr(max)})`
	end,
	SecurityCapabilities = function(v: SecurityCapabilities, _, repr: (any) -> string): string
		const args = {}

		for _, capability in Enum.SecurityCapability:GetEnumItems() do
			if v:Contains(capability) then
				table.insert(args, repr(capability))
			end
		end

		return `SecurityCapabilities.new({table.concat(args, ", ")})`
	end,
	TweenInfo = function(v: TweenInfo, _, repr: (any) -> string): string
		return string.format(
			"TweenInfo.new(%s, %s, %s, %s, %s)",
			repr(v.Time),
			repr(v.EasingStyle),
			repr(v.EasingDirection),
			repr(v.RepeatCount),
			repr(v.Reverses)
		)
	end,
	UDim = function(v: UDim, _, repr: (any) -> string): string
		return `UDim.new({repr(v.Scale)}, {repr(v.Offset)})`
	end,
	UDim2 = function(v: UDim2, _, repr: (any) -> string): string
		const x, y = v.X, v.Y
		return `UDim2.new({repr(x.Scale)}, {repr(x.Offset)}, {repr(y.Scale)}, {repr(y.Offset)})`
	end,
	User = function(v: User, _, repr: (any) -> string): string
		return `User.fromId({repr(v.Id)})`
	end,
	Vector2 = function(v: Vector2, _, repr: (any) -> string): string
		return `Vector2.new({repr(v.X)}, {repr(v.Y)})`
	end,
	Vector3 = function(v: Vector3, _, repr: (any) -> string): string
		return `Vector3.new({repr(v.X)}, {repr(v.Y)}, {repr(v.Z)})`
	end,
}

const function recursive_repr(v: any, context: ReprContext): string
	const v_type = typeof(v)
	const formatter = DEFAULT_FORMATTERS[v_type]

	if formatter ~= nil then
		return formatter(v, context, function(v): string
			return recursive_repr(v, context)
		end)
	end

	return `<{v_type}: {v}>`
end

const function repr(v: any, options: ReprOptions?): string
	const context: ReprContext = {
		options = if options == nil then DEFAULT_OPTIONS else merge_tables(options, DEFAULT_OPTIONS),
		table_depth = 0,
		table_showing = {},
	}

	return recursive_repr(v, context)
end

return repr
