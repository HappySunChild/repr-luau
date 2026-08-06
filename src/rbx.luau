const base_repr = require("./repr")

type RBXOptions = {
	show_instance_full_names: boolean?,
	show_color3_as_decimals: boolean?,
}
export type ReprOptions = base_repr.ReprOptions & RBXOptions
type ReprContext = base_repr.ReprContext & RBXOptions

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

const RBX_FORMATTERS = {
	Axes = function(v: Axes, context: ReprContext): string
		const repr = context.repr
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
	BrickColor = function(v: BrickColor, context: ReprContext): string
		const repr = context.repr
		return `BrickColor.new({repr(v.Name)})`
	end,
	CFrame = function(v: CFrame, context: ReprContext): string
		const repr = context.repr
		const args = {}

		for _, component in { v:GetComponents() } do
			table.insert(args, repr(component))
		end

		return `CFrame.new({table.concat(args, ", ")})`
	end,
	Color3 = function(v: Color3, context: ReprContext): string
		const repr = context.repr

		if context.show_color3_as_decimals then
			return `Color3.new({repr(v.R)}, {repr(v.G)}, {repr(v.B)})`
		end

		return string.format("Color3.fromRGB(%s, %s, %s)", repr(v.R * 255), repr(v.G * 255), repr(v.B * 255))
	end,
	ColorSequence = function(v: ColorSequence, context: ReprContext): string
		const repr = context.repr
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
	ColorSequenceKeypoint = function(v: ColorSequenceKeypoint, context: ReprContext): string
		const repr = context.repr
		return `ColorSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)})`
	end,
	Content = function(v: Content, context: ReprContext): string
		const repr = context.repr
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
	DateTime = function(v: DateTime, context: ReprContext): string
		return `DateTime.fromUnixTimestamp({context.repr(v.UnixTimestamp)})`
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
	Faces = function(v: Faces, context: ReprContext): string
		const repr = context.repr
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
		if not context.show_instance_full_names then
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
					else `[{context.repr(name)}]`
			)

			current = parent
		end

		return table.concat(path, "")
	end,
	NumberRange = function(v: NumberRange, context: ReprContext): string
		const repr = context.repr

		if v.Min == v.Max then
			return `NumberRange.new({repr(v.Min)})`
		end

		return `NumberRange.new({repr(v.Min)}, {repr(v.Max)})`
	end,
	NumberSequence = function(v: NumberSequence, context: ReprContext): string
		const repr = context.repr
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
	NumberSequenceKeypoint = function(v: NumberSequenceKeypoint, context: ReprContext): string
		const repr = context.repr
		const envelope = v.Envelope

		if envelope == 0 then
			return `NumberSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)})`
		end

		return `NumberSequenceKeypoint.new({repr(v.Time)}, {repr(v.Value)}, {repr(envelope)})`
	end,
	PathWaypoint = function(v: PathWaypoint, context: ReprContext): string
		const repr = context.repr
		return `PathWaypoint.new({repr(v.Position)}, {repr(v.Action)}, {repr(v.Label)})`
	end,
	PhysicalProperties = function(v: PhysicalProperties, context: ReprContext): string
		const repr = context.repr
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
	Random = function(): string
		return "Random.new()"
	end,
	Ray = function(v: Ray, context: ReprContext): string
		const repr = context.repr
		return `Ray.new({repr(v.Origin)}, {repr(v.Direction)})`
	end,
	RaycastParams = function(): string
		return "RaycastParams.new()"
	end,
	Rect = function(v: Rect, context: ReprContext): string
		const repr = context.repr
		const min, max = v.Min, v.Max
		return `Rect.new({repr(min.X)}, {repr(min.Y)}, {repr(max.X)}, {repr(max.Y)})`
	end,
	Region3 = function(v: Region3, context: ReprContext): string
		const repr = context.repr
		const min = v.CFrame * (-v.Size / 2)
		const max = v.CFrame * (v.Size / 2)
		return `Region3.new({repr(min)}, {repr(max)})`
	end,
	SecurityCapabilities = function(v: SecurityCapabilities, context: ReprContext): string
		const repr = context.repr
		const args = {}

		for _, capability in Enum.SecurityCapability:GetEnumItems() do
			if v:Contains(capability) then
				table.insert(args, repr(capability))
			end
		end

		return `SecurityCapabilities.new({table.concat(args, ", ")})`
	end,
	TweenInfo = function(v: TweenInfo, context: ReprContext): string
		const repr = context.repr
		return string.format(
			"TweenInfo.new(%s, %s, %s, %s, %s)",
			repr(v.Time),
			repr(v.EasingStyle),
			repr(v.EasingDirection),
			repr(v.RepeatCount),
			repr(v.Reverses)
		)
	end,
	UDim = function(v: UDim, context: ReprContext): string
		const repr = context.repr
		return `UDim.new({repr(v.Scale)}, {repr(v.Offset)})`
	end,
	UDim2 = function(v: UDim2, context: ReprContext): string
		const repr = context.repr
		const x, y = v.X, v.Y
		return `UDim2.new({repr(x.Scale)}, {repr(x.Offset)}, {repr(y.Scale)}, {repr(y.Offset)})`
	end,
	User = function(v: User, context: ReprContext): string
		return `User.fromId({context.repr(v.Id)})`
	end,
	Vector2 = function(v: Vector2, context: ReprContext): string
		const repr = context.repr
		return `Vector2.new({repr(v.X)}, {repr(v.Y)})`
	end,
	Vector3 = function(v: Vector3, context: ReprContext): string
		const repr = context.repr
		return `Vector3.new({repr(v.X)}, {repr(v.Y)}, {repr(v.Z)})`
	end,
}

const DEFAULT_OPTIONS: ReprOptions = {
	show_color3_as_decimals = false,
	show_instance_full_names = true,
	custom_formatters = RBX_FORMATTERS,
}

const function repr_rbx(v: any, options: ReprOptions?): string
	return base_repr(v, if options == nil then DEFAULT_OPTIONS else merge_tables(options, DEFAULT_OPTIONS))
end

return repr_rbx
