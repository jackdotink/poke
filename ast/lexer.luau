--!optimize 2
local ast = require("./ast")
local source = require("./source")

local buf: buffer
local lfs: { number }

local sid: number
local pos: number
local len: number

local brace_count: number
local brace_stack: { number } = {}

local first: number
local second: number

local function byte(c: string)
	return (string.byte(c))
end

local function bump1()
	pos += 1
	
	first = second
	second = if pos + 1 >= len then 0 else buffer.readu8(buf, pos + 1)
end

local function bump1_any()
	pos += 1

	if first == byte("\n") then
		table.insert(lfs, pos)
	end

	first = second
	second = if pos + 1 >= len then 0 else buffer.readu8(buf, pos + 1)
end

local function bump2()
	pos += 2

	first = if pos >= len then 0 else buffer.readu8(buf, pos)
	second = if pos + 1 >= len then 0 else buffer.readu8(buf, pos + 1)
end

local function unbump1()
	pos -= 1

	second = first
	first = if pos >= len then 0 else buffer.readu8(buf, pos)
end

local function is_whitespace(c: number): boolean
	return c == byte(" ") or (byte("\t") <= c and c <= byte("\r"))
end

local function is_digit(c: number): boolean
	return byte("0") <= c and c <= byte("9")
end

local function is_alpha(c: number): boolean
	if type(c) == "string" then
		error("how did we get here")
	end

	return (byte("a") <= c and c <= byte("z")) or (byte("A") <= c and c <= byte("Z"))
end

local function number(): "number" | "error"
	local underscore = false
	local start = pos
	local base = 10

	if first == byte("0") then
		bump1()

		if first == byte("x") or first == byte("X") then
			bump1()
			base = 16
		elseif first == byte("b") or first == byte("B") then
			bump1()
			base = 2
		end
	end

	while is_digit(first) or first == byte(".") or first == byte("_") do
		if first == byte("_") then
			underscore = true
		end

		bump1()
	end

	if first == byte("e") or first == byte("E") then
		bump1()

		if first == byte("+") or first == byte("-") then
			bump1()
		end
	end

	while is_digit(first) or is_alpha(first) or first == byte("_") do
		bump1()
	end

	local text =
		if base == 10 then buffer.readstring(buf, start, pos - start)
		else buffer.readstring(buf, start + 2, pos - start - 2)

	if underscore then
		text = string.gsub(text, "_", "")
	end

	if tonumber(text, base) then
		return "number"
	else
		return "error"
	end
end

local function string_backslash()
	if first == byte("\r") then
		if second == byte("\n") then
			bump2()
			table.insert(lfs, pos)
		else
			bump1()
		end
	elseif first == byte("z") then
		bump1()

		while is_whitespace(first) do
			bump1_any()
		end
	else
		bump1_any()
	end
end

local function quoted_string(): "string" | "error"
	local delim = first
	bump1()

	while first ~= delim do
		if first == 0 or first == byte("\n") or first == byte("\r") then
			return "error"
		elseif first == byte("\\") then
			bump1()
			string_backslash()
		else
			bump1()
		end
	end

	bump1()
	return "string"
end

local function long_seperator(): number
	local count = 0

	while first == byte("=") do
		bump1()
		count += 1
	end

	return count
end

local function long_string(eqs: number): "string" | "error"
	bump1()

	while true do
		if first == byte("]") then
			bump1()

			if long_seperator() == eqs and first == byte("]") then
				bump1()
				return "string"
			end
		elseif first == 0 then
			return "error"
		else
			bump1_any()
		end
	end
end

local function istring_section(
	from: "start" | "middle"
): "simpleistring" | "firstistring" | "middleistring" | "lastistring" | "error"
	while first ~= byte("`") do
		if first == 0 or first == byte("\n") or first == byte("\r") then
			return "error"
		elseif first == byte("\\") then
			bump1()

			if first == byte("u") then
				if second == byte("{") then
					bump2()
				else
					bump1()
				end
			else
				string_backslash()
			end
		elseif first == byte("{") then
			bump1()

			if first == byte("{") then
				bump1()
				return "error"
			else
				table.insert(brace_stack, brace_count)

				if from == "start" then
					return "firstistring"
				else
					return "middleistring"
				end
			end
		else
			bump1()
		end
	end

	bump1()

	if from == "start" then
		return "simpleistring"
	else
		return "lastistring"
	end
end

local function comment(): "comment" | "error"
	if first == byte("[") then
		bump1()
		local eqs = long_seperator()

		if first == byte("[") then
			local result = long_string(eqs)

			if result == "error" then
				return "error"
			else
				return "comment"
			end
		end
	end

	while first ~= 0 and first ~= byte("\n") do
		bump1()
	end

	return "comment"
end

local identifiers = {
	["local"] = true,
	["end"] = true,
	["elseif"] = true,
	["else"] = true,
	["then"] = true,
	["true"] = true,
	["return"] = true,
	["repeat"] = true,
	["function"] = true,
	["for"] = true,
	["false"] = true,
	["if"] = true,
	["in"] = true,
	["do"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["and"] = true,
	["break"] = true,
	["while"] = true,
	["until"] = true,
}

local identifierd = {
	[byte("l")] = true,
	[byte("e")] = true,
	[byte("t")] = true,
	[byte("r")] = true,
	[byte("f")] = true,
	[byte("i")] = true,
	[byte("d")] = true,
	[byte("n")] = true,
	[byte("o")] = true,
	[byte("a")] = true,
	[byte("b")] = true,
	[byte("w")] = true,
	[byte("u")] = true,
}

local function identifier(): string
	local d = first
	local start = pos
	
	repeat
		bump1()
	until not (is_alpha(first) or is_digit(first) or first == byte("_"))

	if identifierd[d] then
		local text = buffer.readstring(buf, start, pos - start)
		return if identifiers[text] then text else "identifier"
	else
		return "identifier"
	end
end

local function symbol(): string
	local c = first
	bump1()

	if c == byte(".") then
		if first == byte(".") then
			if second == byte(".") then
				bump2()
				return "..."
			elseif second == byte("=") then
				bump2()
				return "..="
			else
				bump1()
				return ".."
			end
		elseif is_digit(first) then
			unbump1()
			return number()
		else
			return "."
		end
	elseif c == byte("(") then
		return "("
	elseif c == byte(")") then
		return ")"
	elseif c == byte("=") then
		if first == byte("=") then
			bump1()
			return "=="
		else
			return "="
		end
	elseif c == byte(",") then
		return ","
	elseif c == byte(":") then
		if first == byte(":") then
			bump1()
			return "::"
		else
			return ":"
		end
	elseif c == byte("<") then
		if first == byte("=") then
			bump1()
			return "<="
		else
			return "<"
		end
	elseif c == byte(">") then
		if first == byte("=") then
			bump1()
			return ">="
		else
			return ">"
		end
	elseif c == byte("]") then
		return "]"
	elseif c == byte("|") then
		return "|"
	elseif c == byte("?") then
		return "?"
	elseif c == byte("+") then
		if first == byte("=") then
			bump1()
			return "+="
		else
			return "+"
		end
	elseif c == byte("-") then
		if first == byte("=") then
			bump1()
			return "-="
		elseif first == byte(">") then
			bump1()
			return "->"
		else
			return "-"
		end
	elseif c == byte("*") then
		if first == byte("=") then
			bump1()
			return "*="
		else
			return "*"
		end
	elseif c == byte("#") then
		return "#"
	elseif c == byte("&") then
		return "&"
	elseif c == byte("~") then
		if first == byte("=") then
			bump1()
			return "~="
		else
			return "error"
		end
	elseif c == byte("/") then
		if first == byte("/") then
			if second == byte("=") then
				bump2()
				return "//="
			else
				bump1()
				return "//"
			end
		elseif first == byte("=") then
			bump1()
			return "/="
		else
			return "/"
		end
	elseif c == byte("^") then
		if first == byte("=") then
			bump1()
			return "^="
		else
			return "^"
		end
	elseif c == byte(";") then
		return ";"
	elseif c == byte("%") then
		if first == byte("=") then
			bump1()
			return "%="
		else
			return "%"
		end
	elseif c == 0 then
		return "eof"
	else
		return "error"
	end
end

local function next(): (string, ast.Span)
	while true do
		if is_whitespace(first) then
			bump1_any()
		elseif first == byte("-") and second == byte("-") then
			bump2()
			comment()
		else
			break
		end
	end

	local start = pos

	if is_alpha(first) or first == byte("_") then
		return identifier(), vector.create(start, pos, sid)
	elseif is_digit(first) then
		return number(), vector.create(start, pos, sid)
	elseif first == byte("'") or first == byte('"') then
		return quoted_string(), vector.create(start, pos, sid)
	elseif first == byte("`") then
		bump1()
		return istring_section("start"), vector.create(start, pos, sid)
	elseif first == byte("{") then
		bump1()
		brace_count += 1
		return "{", vector.create(start, pos, sid)
	elseif first == byte("}") then
		local brace_stack_len = #brace_stack

		if brace_stack_len ~= 0 and brace_stack[brace_stack_len] == brace_count then
			brace_stack[brace_stack_len] = nil
			return istring_section("middle"), vector.create(start, pos, sid)
		else
			bump1()
			brace_count -= 1
			return "}", vector.create(start, pos, sid)
		end
	elseif first == byte("[") then
		bump1()
		local eqs = long_seperator()

		if first == byte("[") then
			return long_string(eqs), vector.create(start, pos, sid)
		elseif eqs == 0 then
			return "[", vector.create(start, pos, sid)
		else
			return "error", vector.create(start, pos, sid)
		end
	else
		return symbol(), vector.create(start, pos, sid)
	end
end

local function load(id: number)
	sid = id
	lfs = source.fill(id)
	buf = source.text(id)
	len = buffer.len(buf)
	pos = 0

	assert(#lfs == 0, "cannot load source that already has line info")
	
	brace_count = 0
	table.clear(brace_stack)

	if len ~= 0 then
		first = buffer.readu8(buf, 0)

		if len ~= 1 then
			second = buffer.readu8(buf, 1)
		else
			second = 0
		end
	else
		first = 0
		second = 0
	end
end

return {
	next = next,
	load = load,
}
