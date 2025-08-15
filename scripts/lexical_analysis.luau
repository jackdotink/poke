local buf: buffer

local kind: string

local next: () -> ()
local load: (buffer) -> ()

do -- Lexer
	local pos: number
	local len: number

	local brace_count: number
	local brace_stack: { number } = {}

	local function byte(c: string): number
		return (string.byte(c))
	end

	local function first(): number
		if pos >= len then
			return 0
		end

		return (buffer.readu8(buf, pos))
	end

	local function second(): number
		if pos + 1 >= len then
			return 0
		end

		return (buffer.readu8(buf, pos + 1))
	end

	local function bump()
		pos += 1
	end

	local function is_whitespace(c: number): boolean
		return c == byte(" ") or (c <= byte("\r") and byte("\t") <= c)
	end

	local function is_digit(c: number): boolean
		return byte("0") <= c and c <= byte("9")
	end

	local function is_alpha(c: number): boolean
		return (byte("a") <= c and c <= byte("z")) or (byte("A") <= c and c <= byte("Z"))
	end

	local function number(): "number" | "error"
		local underscore = false
		local start = pos
		local base = 10

		local c = first()
		if c == byte("0") then
			bump()
			c = first()

			if c == byte("x") or c == byte("X") then
				bump()
				c = first()
				base = 16
			elseif c == byte("b") or c == byte("B") then
				bump()
				c = first()
				base = 2
			end
		end

		while is_digit(c) or c == byte(".") or c == byte("_") do
			if c == byte("_") then
				underscore = true
			end

			bump()
			c = first()
		end

		if c == byte("e") or c == byte("E") then
			bump()
			c = first()

			if c == byte("+") or c == byte("-") then
				bump()
				c = first()
			end
		end

		while is_digit(c) or is_alpha(c) or c == byte("_") do
			bump()
			c = first()
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
		local c = first()

		if c == byte("\r") then
			bump()
			c = first()

			if c == byte("\n") then
				bump()
			end
		elseif c == byte("z") then
			bump()

			while is_whitespace(first()) do
				bump()
			end
		else
			bump()
		end
	end

	local function quoted_string(): "string" | "error"
		local delim = first()
		bump()
		local c = first()

		while c ~= delim do
			if c == 0 or c == byte("\n") or c == byte("\r") then
				return "error"
			elseif c == byte("\\") then
				bump()
				string_backslash()
			else
				bump()
			end

			c = first()
		end

		bump()
		return "string"
	end

	local function long_seperator(): number
		local count = 0

		while first() == byte("=") do
			bump()
			count += 1
		end

		return count
	end

	local function long_string(eqs: number): "string" | "error"
		bump()

		while true do
			local c = first()

			if c == byte("]") then
				bump()

				if long_seperator() == eqs and first() == byte("]") then
					bump()
					return "string"
				end
			elseif c == 0 then
				return "error"
			else
				bump()
			end
		end
	end

	local function istring_section(
		from: "start" | "middle"
	): "simpleistring" | "firstistring" | "middleistring" | "lastistring" | "error"
		local c = first()

		while c ~= byte("`") do
			if c == 0 or c == byte("\n") or c == byte("\r") then
				return "error"
			elseif c == byte("\\") then
				bump()

				if first() == byte("u") then
					bump()

					if first() == byte("{") then
						bump()
					end
				else
					string_backslash()
				end
			elseif c == byte("{") then
				bump()

				if first() == byte("{") then
					bump()
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
				bump()
			end

			c = first()
		end

		bump()

		if from == "start" then
			return "simpleistring"
		else
			return "lastistring"
		end
	end

	local function comment(): "comment" | "error"
		local c = first()

		if c == byte("[") then
			bump()
			local eqs = long_seperator()

			if first() == byte("[") then
				local result = long_string(eqs)

				if result == "error" then
					return "error"
				else
					return "comment"
				end
			end
		end

		c = first()

		while c ~= 0 and c ~= byte("\n") do
			bump()
			c = first()
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

	function next()
		local c = first()

		while true do
			if is_whitespace(c) then
				bump()
				c = first()
			elseif c == byte("-") and second() == byte("-") then
				bump()
				bump()

				comment()
				c = first()
			else
				break
			end
		end

		local start = pos

		if is_alpha(c) or c == byte("_") then
			local d = c

			repeat
				bump()
				c = first()
			until not (is_alpha(c) or is_digit(c) or c == byte("_"))

			if identifierd[d] then
				local text = buffer.readstring(buf, start, pos - start)
				kind = if identifiers[text] then text else "identifier"
			else
				kind = "identifier"
			end
		elseif is_digit(c) then
			kind = number()
		elseif c == byte('"') or c == byte("'") then
			kind = quoted_string()
		elseif c == byte("`") then
			bump()
			kind = istring_section("start")
		elseif c == byte("{") then
			brace_count += 1
			bump()
			kind = "{"
		elseif c == byte("}") then
			local brace_stack_len = #brace_stack

			if brace_stack_len ~= 0 and brace_stack[brace_stack_len] == brace_count then
				brace_stack[brace_stack_len] = nil
				kind = istring_section("middle")
			else
				brace_count -= 1
				bump()
				kind = "}"
			end
		elseif c == byte("[") then
			bump()

			local eqs = long_seperator()

			if first() == byte("[") then
				kind = long_string(eqs)
			elseif eqs == 0 then
				kind = "["
			else
				kind = "error"
			end
		else
			bump()

			if c == byte(",") then
				kind = ","
			elseif c == byte("(") then
				kind = "("
			elseif c == byte(")") then
				kind = ")"
			elseif c == byte("=") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "=="
				else
					kind = "="
				end
			elseif c == byte(".") then
				c = first()

				if c == byte(".") then
					bump()
					c = first()

					if c == byte(".") then
						bump()
						kind = "..."
					elseif c == byte("=") then
						bump()
						kind = "..="
					else
						kind = ".."
					end
				elseif is_digit(c) then
					pos -= 1
					kind = number()
				else
					kind = "."
				end
			elseif c == byte(":") then
				c = first()

				if c == byte(":") then
					bump()
					kind = "::"
				else
					kind = ":"
				end
			elseif c == byte("<") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "<="
				else
					kind = "<"
				end
			elseif c == byte(">") then
				c = first()

				if c == byte("=") then
					bump()
					kind = ">="
				else
					kind = ">"
				end
			elseif c == byte("]") then
				kind = "]"
			elseif c == byte("|") then
				kind = "|"
			elseif c == byte("?") then
				kind = "?"
			elseif c == byte("+") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "+="
				else
					kind = "+"
				end
			elseif c == byte("-") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "-="
				elseif c == byte(">") then
					bump()
					kind = "->"
				else
					kind = "-"
				end
			elseif c == byte("*") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "*="
				else
					kind = "*"
				end
			elseif c == byte("#") then
				kind = "#"
			elseif c == byte("&") then
				kind = "&"
			elseif c == byte("~") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "~="
				else
					kind = "error"
				end
			elseif c == byte("/") then
				c = first()

				if c == byte("/") then
					bump()
					c = first()

					if c == byte("=") then
						bump()
						kind = "//="
					else
						kind = "//"
					end
				elseif c == byte("=") then
					bump()
					kind = "/="
				else
					kind = "/"
				end
			elseif c == byte("^") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "^="
				else
					kind = "^"
				end
			elseif c == byte(";") then
				kind = ";"
			elseif c == byte("%") then
				c = first()

				if c == byte("=") then
					bump()
					kind = "%="
				else
					kind = "%"
				end
			elseif c == 0 then
				kind = "eof"
			else
				kind = "error"
			end
		end
	end

	function load(text: string)
		buf = buffer.fromstring(text)
		len = buffer.len(buf)
		pos = 0

		brace_count = 0
		table.clear(brace_stack)
	end
end

local acc: { [string]: number } = {}

local files = require("../extern/files")
for i, file in files do
	if string.sub(file, -4, -1) == ".lua" then
		file = string.sub(file, 1, -5)
	else
		file = string.sub(file, 1, -6)
	end

	if string.sub(file, -5, -1) == "/init" then
		file = string.sub(file, 1, -6)
	end

	files[i] = file
end

for _, file in files do
	local str = (require)("../" .. file).str
	
	load(str)
	next()

	while kind ~= "eof" do
		if acc[kind] then
			acc[kind] += 1
		else
			acc[kind] = 1
		end

		next()
	end
end

local sorted: { string } = {}

for kind in acc do
	table.insert(sorted, kind)
end

table.sort(sorted, function(k1, k2)
	return acc[k1] > acc[k2]
end)

for _, kind in sorted do
	print(`{kind}: {acc[kind]}`)
end
