export type SourceId = { __newtype: "sourceid" }

local sources: {{
	name: string,
	code: string,
	lines: { number }?,
}} = {}

local function add(name: string, code: string): SourceId
	local id = #sources + 1
	sources[id] = {
		name = name,
		code = code,
		lines = nil :: { number }?,
	}

	return id :: any
end

local function get_name(id: SourceId): string
	local id: number = id :: any
	return sources[id].name
end

local function get_code(id: SourceId): string
	local id: number = id :: any
	return sources[id].code
end

local function read_span(span: vector): string
	local code = sources[(span :: any).z].code

	return string.sub(code, (span :: any).x, (span :: any).y)
end

return {
	add = add,
	get_name = get_name,
	get_code = get_code,
	read_span = read_span,
}
