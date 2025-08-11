--!optimize 2

local ast = require("./ast")

local debug = false

type Error = {
	msg: string,
	span: ast.Span,
}

local function push<T>(t: { T }, v: T)
	t[#t + 1] = v
end

local source: buffer

local lines: { number }

local last_span: ast.Span

local current_kind: string
local current_span: ast.Span

local lookahead_kind: string
local lookahead_span: ast.Span

local next: () -> ()
local load: (buffer) -> ()

do -- Lexer
	local sid: number
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

		return (buffer.readu8(source, pos))
	end

	local function second(): number
		if pos + 1 >= len then
			return 0
		end

		return (buffer.readu8(source, pos + 1))
	end

	local function bump()
		if pos ~= len then
			pos += 1
		end
	end

	local function bump_any()
		if first() == byte("\n") then
			table.insert(lines, pos + 1)
		end

		bump()
	end

	local function is_whitespace(c: number): boolean
		return c == byte(" ") or (c <= byte("\f") and byte("\t") <= c)
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
			if base == 10 then buffer.readstring(source, start, pos - start)
			else buffer.readstring(source, start + 2, pos - start - 2)

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
				table.insert(lines, pos + 1)
				bump()
			end
		elseif c == byte("z") then
			bump()

			while is_whitespace(first()) do
				bump_any()
			end
		else
			bump_any()
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
				bump_any()
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
		last_span = current_span

		current_kind = lookahead_kind
		current_span = lookahead_span

		local c = first()

		while true do
			if is_whitespace(c) then
				bump_any()
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
				local text = buffer.readstring(source, start, pos - start)
				lookahead_kind = if identifiers[text] then text else "identifier"
			else
				lookahead_kind = "identifier"
			end
		elseif is_digit(c) then
			lookahead_kind = number()
		elseif c == byte('"') or c == byte("'") then
			lookahead_kind = quoted_string()
		elseif c == byte("`") then
			bump()
			lookahead_kind = istring_section("start")
		elseif c == byte("{") then
			brace_count += 1
			bump()
			lookahead_kind = "{"
		elseif c == byte("}") then
			local brace_stack_len = #brace_stack

			if brace_stack_len ~= 0 and brace_stack[brace_stack_len] == brace_count then
				brace_stack[brace_stack_len] = nil
				lookahead_kind = istring_section("middle")
			else
				brace_count -= 1
				bump()
				lookahead_kind = "}"
			end
		elseif c == byte("[") then
			bump()

			local eqs = long_seperator()

			if first() == byte("[") then
				lookahead_kind = long_string(eqs)
			elseif eqs == 0 then
				lookahead_kind = "["
			else
				lookahead_kind = "error"
			end
		else
			bump()

			if c == byte(",") then
				lookahead_kind = ","
			elseif c == byte("(") then
				lookahead_kind = "("
			elseif c == byte(")") then
				lookahead_kind = ")"
			elseif c == byte("=") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "=="
				else
					lookahead_kind = "="
				end
			elseif c == byte(".") then
				c = first()

				if c == byte(".") then
					bump()
					c = first()

					if c == byte(".") then
						bump()
						lookahead_kind = "..."
					elseif c == byte("=") then
						bump()
						lookahead_kind = "..="
					else
						lookahead_kind = ".."
					end
				elseif is_digit(c) then
					pos -= 1
					lookahead_kind = number()
				else
					lookahead_kind = "."
				end
			elseif c == byte(":") then
				c = first()

				if c == byte(":") then
					bump()
					lookahead_kind = "::"
				else
					lookahead_kind = ":"
				end
			elseif c == byte("<") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "<="
				else
					lookahead_kind = "<"
				end
			elseif c == byte(">") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = ">="
				else
					lookahead_kind = ">"
				end
			elseif c == byte("]") then
				lookahead_kind = "]"
			elseif c == byte("|") then
				lookahead_kind = "|"
			elseif c == byte("?") then
				lookahead_kind = "?"
			elseif c == byte("+") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "+="
				else
					lookahead_kind = "+"
				end
			elseif c == byte("-") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "-="
				elseif c == byte(">") then
					bump()
					lookahead_kind = "->"
				else
					lookahead_kind = "-"
				end
			elseif c == byte("*") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "*="
				else
					lookahead_kind = "*"
				end
			elseif c == byte("#") then
				lookahead_kind = "#"
			elseif c == byte("&") then
				lookahead_kind = "&"
			elseif c == byte("~") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "~="
				else
					lookahead_kind = "error"
				end
			elseif c == byte("/") then
				c = first()

				if c == byte("/") then
					bump()
					c = first()

					if c == byte("=") then
						bump()
						lookahead_kind = "//="
					else
						lookahead_kind = "//"
					end
				elseif c == byte("=") then
					bump()
					lookahead_kind = "/="
				else
					lookahead_kind = "/"
				end
			elseif c == byte("^") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "^="
				else
					lookahead_kind = "^"
				end
			elseif c == byte(";") then
				lookahead_kind = ";"
			elseif c == byte("%") then
				c = first()

				if c == byte("=") then
					bump()
					lookahead_kind = "%="
				else
					lookahead_kind = "%"
				end
			elseif c == 0 then
				lookahead_kind = "eof"
			else
				lookahead_kind = "error"
			end
		end

		lookahead_span = vector.create(start, pos, sid)
	end

	function load(source_: buffer, sid_: number)
		source = source_

		sid = sid_
		pos = 0
		len = buffer.len(source)

		lines = { 1 }

		brace_count = 0
		table.clear(brace_stack)

		next()
		next()
	end
end

local function display(kind: string, span: ast.Span): string
	if kind == "identifier"
		or kind == "number"
		or kind == "string"
		or kind == "attribute"
	then
		return kind .. " '" .. buffer.readstring(source, span.x, span.y - span.x) .. "'"
	elseif kind == "error" then
		return "'" .. buffer.readstring(source, span.x, span.y - span.x) .. "'"
	else
		return "'" .. kind .. "'"
	end
end

local function report(msg: string, span: ast.Span?): never
	local report: Error = {
		msg = msg,
		span = span or current_span,
		line = #lines,
	}

	error(report)
end

local function consume(kind: string?)
	if debug then
		assert(kind == nil or current_kind == kind, "attempted to consume incorrect kind")
	end

	next()
end

local function consume_identifier(): ast.Identifier
	if debug then
		assert(current_kind == "identifier", "attempted to consume non-identifier")
	end

	local identifier: ast.Identifier = { span = current_span }
	next()
	return identifier
end

local function consume_number(): ast.Number
	if debug then
		assert(current_kind == "number", "attempted to consume non-number")
	end

	local number: ast.Number = { span = current_span }
	next()
	return number
end

local function consume_string(): ast.String
	if debug then
		assert(current_kind == "string", "attempted to consume non-string")
	end

	local string: ast.String = { span = current_span }
	next()
	return string
end

local function consume_attribute(): ast.Attribute
	if debug then
		assert(current_kind == "attribute", "attempted to consume non-attribute")
	end

	local attribute: ast.Attribute = { span = current_span }
	next()
	return attribute
end

local function consume_istring(): ast.IString
	if debug then
		assert(
			current_kind == "simpleistring"
				or current_kind == "firstistring"
				or current_kind == "middleistring"
				or current_kind == "lastistring",
			"attempted to consume non-istring"
		)
	end

	local istring: ast.IString = { span = current_span }
	next()
	return istring
end

local expect_failure
function expect_failure(kind: string): never
	return report(`expected {display(kind, vector.zero)} but got {display(current_kind, current_span)} instead`)
end

local function expect(kind: string)
	if current_kind == kind then
		next()
	else
		expect_failure(kind)
	end
end

local function expect_identifier(): ast.Identifier
	if current_kind == "identifier" then
		return consume_identifier()
	else
		return expect_failure("identifier")
	end
end

local function open(): number
	return current_span.x
end

local function close(start: number): ast.Span
	return vector.create(start, last_span.y, last_span.z)
end

local parse_block: () -> ast.Block
local parse_expr: () -> ast.Expr
local parse_var: () -> ast.Var
local parse_type: () -> ast.Type
local parse_type_or_type_pack: () -> ast.Type | ast.TypePack

local function should_parse_tail_type(): boolean
	return current_kind == "..." or (current_kind == "identifier" and lookahead_kind == "...")
end

local function parse_tail_type(): ast.TailType
	local start = open()

	if current_kind == "..." then
		consume("...")
		local type = parse_type()

		return {
			kind = "variadic" :: "variadic",
			span = close(start),

			type = type,
		}
	else
		local name = consume_identifier()
		consume("...")

		return {
			kind = "generic" :: "generic",
			span = close(start),

			name = name,
		}
	end
end

local function parse_list_type_pack(): ast.ListTypePack
	local start = open()
	consume("(")

	local types: { ast.Type } = {}

	while true do
		if should_parse_tail_type() then
			local tail = parse_tail_type()
			expect(")")

			return {
				kind = "list" :: "list",
				span = close(start),

				types = types,
				tail = tail,
			}
		end

		push(types, parse_type())

		if current_kind == "," then
			consume(",")
		else
			return {
				kind = "list" :: "list",
				span = close(start),

				types = types,
				tail = nil,
			}
		end
	end
end

local function parse_type_pack(): ast.TypePack
	if should_parse_tail_type() then
		return parse_tail_type()
	elseif current_kind == "(" then
		return parse_list_type_pack()
	else
		return report(`expected type pack, found {display(current_kind, current_span)} instead`)
	end
end

local function parse_generic_decl(): ast.GenericDecl
	local start = open()
	expect("<")

	local names: { ast.Identifier } = {}
	local packs: { ast.Identifier } = {}

	while true do
		if current_kind == "identifier" and lookahead_kind == "..." then
			break
		end

		push(names, expect_identifier())

		if current_kind == "," then
			consume(",")
		else
			expect(">")

			return {
				span = close(start),

				names = names,
				packs = packs,
			}
		end
	end

	while true do
		push(packs, expect_identifier())
		expect("...")

		if current_kind == "," then
			consume(",")
		else
			expect(">")

			return {
				span = close(start),

				names = names,
				packs = packs,
			}
		end
	end
end

local function parse_generic_decl_with_defaults(): ast.GenericDeclWithDefaults
	local start = open()
	expect("<")

	local names_without_defaults: index<ast.GenericDeclWithDefaults, "names_without_defaults"> = {}
	local names_with_defaults: index<ast.GenericDeclWithDefaults, "names_with_defaults"> = {}
	local packs_without_defaults: index<ast.GenericDeclWithDefaults, "packs_without_defaults"> = {}
	local packs_with_defaults: index<ast.GenericDeclWithDefaults, "packs_with_defaults"> = {}

	local seen_default = false

	while true do
		if current_kind == "identifier" and lookahead_kind == "..." then
			break
		end

		local name = expect_identifier()

		if current_kind == "=" or seen_default then
			seen_default = true

			expect("=")

			local type = parse_type()
			push(names_with_defaults, { name = name, default = type })
		else
			push(names_without_defaults, name)
		end

		if current_kind == "," then
			consume(",")
		else
			expect(">")

			return {
				span = close(start),

				names_without_defaults = names_without_defaults,
				names_with_defaults = names_with_defaults,
				packs_without_defaults = packs_without_defaults,
				packs_with_defaults = packs_with_defaults,
			}
		end
	end

	while true do
		local name = expect_identifier()
		expect("...")

		if current_kind == "=" or seen_default then
			seen_default = true

			expect("=")

			local default = parse_type_pack()
			push(packs_with_defaults, {
				name = name,
				default = default,
			})
		else
			push(packs_without_defaults, name)
		end

		if current_kind == "," then
			consume(",")
		else
			expect(">")

			return {
				span = close(start),

				names_without_defaults = names_without_defaults,
				names_with_defaults = names_with_defaults,
				packs_without_defaults = packs_without_defaults,
				packs_with_defaults = packs_with_defaults,
			}
		end
	end
end

local function parse_name_type(): ast.Type_Name
	local start = open()

	local name = consume_identifier()
	local prefix: ast.Identifier? = nil

	if current_kind == "." then
		prefix = name
		consume(".")
		name = expect_identifier()
	end

	if current_kind == "<" then
		consume("<")
		local generics: { ast.TypeArg } = {}

		if current_kind ~= ">" then
			while true do
				push(generics, parse_type_or_type_pack())

				if current_kind == "," then
					consume(",")
				else
					break
				end
			end
		end

		expect(">")
		return {
			kind = "name" :: "name",
			span = close(start),

			prefix = prefix,
			name = name,
			generics = generics,
		}
	end

	return {
		kind = "name" :: "name",
		span = close(start),

		prefix = prefix,
		name = name,
		generics = nil,
	}
end

local function parse_table_type(): ast.Type_Table | ast.Type_Array
	local start = open()

	consume("{")
	local had_indexer = false
	local fields: { ast.TableTypeField } = {}

	while current_kind ~= "}" do
		local field_start = open()
		local access_span: ast.Span = vector.zero
		local access: ("read" | "write")? = nil

		if current_kind == "identifier" and lookahead_kind ~= ":" then
			local text = buffer.readstring(source, current_span.x, current_span.y - current_span.x)

			if text == "read" or text == "write" then
				access_span = current_span
				access = text
				consume("identifier")
			end
		end

		if current_kind == "[" then
			consume("[")

			if current_kind == "string" and lookahead_kind == "]" then
				local key = consume_string()
				consume("]")
				expect(":")
				local type = parse_type()

				push(fields, {
					kind = "string" :: "string",
					span = close(field_start),

					access = access,
					key = key,
					type = type,
				})
			else
				local index = parse_type()
				expect("]")
				expect(":")
				local value = parse_type()

				if had_indexer then
					report("table types cannot have more than one indexer", close(field_start))
				else
					had_indexer = true
				end

				push(fields, {
					kind = "indexer" :: "indexer",
					span = close(field_start),

					access = access,
					index = index,
					value = value,
				})
			end
		elseif current_kind == "identifier" and lookahead_kind == ":" then
			local key = consume_identifier()
			consume(":")
			local type = parse_type()

			push(fields, {
				kind = "name" :: "name",
				span = close(field_start),

				access = access,
				key = key,
				type = type,
			})
		elseif #fields == 0 then
			local type = parse_type()
			expect("}")

			if access ~= nil then
				report(`'{access}' keyword is illegal in this position`, access_span)
			end

			return {
				kind = "array" :: "array",
				span = close(start),

				type = type,
			}
		end

		if current_kind == "," then
			consume(",")
		else
			break
		end
	end

	expect("}")

	return {
		kind = "table" :: "table",
		span = close(start),

		fields = fields,
	}
end

local function parse_function_type(): ast.Type_Function | ast.Type_Paren
	local start = open()

	local generics = if current_kind == "<" then parse_generic_decl() else nil

	expect("(")
	local params: {{ name: ast.Identifier?, type: ast.Type }} = {}
	local tail: ast.TailType?

	if current_kind ~= ")" then
		while true do
			if should_parse_tail_type() then
				tail = parse_tail_type()
				break
			end

			if current_kind == "identifier" and lookahead_kind == ":" then
				local name = consume_identifier()
				consume(":")
				local type = parse_type()

				push(params, { name = name, type = type })
			else
				push(params, { type = parse_type() })
			end

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end
	end

	expect(")")

	if current_kind ~= "->" and #params == 1 and not params[1].name and not generics then
		return {
			kind = "paren" :: "paren",
			span = close(start),

			type = params[1].type,
		}
	end

	expect("->")

	local ret = parse_type_or_type_pack()

	return {
		kind = "function" :: "function",
		span = close(start),

		generics = generics,
		params = params,
		tail = tail,
		ret = ret,
	}
end

local function parse_simple_type(): ast.Type
	local start = open()

	if current_kind == "nil" then
		consume("nil")
		return { kind = "nil" :: "nil", span = close(start) }
	elseif current_kind == "true" then
		consume("true")
		return { kind = "boolean" :: "boolean", span = close(start), value = true }
	elseif current_kind == "false" then
		consume("false")
		return { kind = "boolean" :: "boolean", span = close(start), value = false }
	elseif current_kind == "string" then
		local string = consume_string()
		return { kind = "string" :: "string", span = close(start), string = string }
	elseif current_kind == "identifier" then
		if buffer.readstring(source, current_span.x, current_span.y - current_span.x) == "typeof" then
			consume("identifier")
			expect("(")
			local expr = parse_expr()
			expect(")")

			return { kind = "typeof" :: "typeof", span = close(start), expr = expr }
		else
			return parse_name_type()
		end
	elseif current_kind == "{" then
		return parse_table_type()
	elseif current_kind == "<" or current_kind == "(" then
		return parse_function_type()
	else
		return report(`expected type, but got {display(current_kind, current_span)} instead`)
	end
end

local function parse_type_suffix(base: ast.Type?): ast.Type
	local start = open()

	local types: { ast.Type } = {}
	local leading = base == nil
	local is_union, is_intersection = false, false

	if leading then
		if current_kind == "|" then
			is_union = true
			consume("|")
		elseif current_kind == "&" then
			is_intersection = true
			consume("&")
		else
			error("invalid leading token")
		end
	else
		start = (base :: any).span.x
	end

	local current: ast.Type? = base

	while true do
		local type: ast.Type

		if current then
			type = current
			current = nil
		else
			type = parse_simple_type()
		end

		if current_kind == "?" then
			if is_intersection then
				report("optional types cannot be used in intersections")
			end

			is_union = true
			consume("?")
			current = {
				kind = "optional" :: "optional",
				span = close(type.span.x),
				type = type,
			}
		elseif current_kind == "|" then
			if is_intersection then
				report("unions and intersections cannot be mixed")
			end

			is_union = true
			consume("|")
			push(types, type)
		elseif current_kind == "&" then
			if is_union then
				report("unions and intersections cannot be mixed")
			end

			consume("&")
			push(types, type)
		elseif #types == 0 and leading then
			return type
		else
			push(types, type)
			break
		end
	end

	if #types == 1 and not is_union and not is_intersection then
		return types[1]
	end

	if debug then
		assert(is_union or is_intersection, "reached end of parse_type_suffix without | or & set")
	end

	if is_union then
		return {
			kind = "union" :: "union",
			span = close(start),

			types = types,
		}
	else
		return {
			kind = "intersection" :: "intersection",
			span = close(start),

			types = types,
		}
	end
end

function parse_type(): ast.Type
	if current_kind == "|" or current_kind == "&" then
		return parse_type_suffix(nil)
	else
		return parse_type_suffix(parse_simple_type())
	end
end

function parse_type_or_type_pack(): ast.Type | ast.TypePack
	if should_parse_tail_type() then
		return parse_tail_type()
	elseif current_kind ~= "(" then
		return parse_type()
	end

	local start = open()
	local force_function = false

	consume("(")

	local params: {{ name: ast.Identifier?, type: ast.Type }} = {}
	local tail: ast.TailType? = nil

	if current_kind ~= ")" then
		while true do
			if should_parse_tail_type() then
				tail = parse_tail_type()
				break
			end

			if current_kind == "identifier" and lookahead_kind == ":" then
				force_function = true
				local name = consume_identifier()

				consume(":")
				local type = parse_type()

				push(params, { name = name, type = type })
			else
				push(params, { type = parse_type() })
			end

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end
	end

	expect(")")
	local has_return = current_kind == "->"

	if not force_function and not has_return and not tail and #params == 1 then
		return parse_type_suffix({
			kind = "paren" :: "paren",
			span = close(start),

			type = params[1].type,
		})
	elseif not force_function and not has_return then
		local types: { ast.Type } = {}
		for i, param in params do
			types[i] = param.type
		end

		return {
			kind = "list" :: "list",
			span = close(start),

			types = types,
			tail = tail,
		}
	else
		expect("->")
		local ret = parse_type_or_type_pack()

		return {
			kind = "function" :: "function",
			span = close(start),

			generics = nil :: ast.GenericDecl?,
			params = params,
			tail = tail,
			ret = ret,
		}
	end
end

local function parse_binding(): ast.Binding
	local start = open()
	local name = expect_identifier()

	if current_kind == ":" then
		consume(":")
		local type = parse_type()

		return {
			span = close(start),
			name = name,
			type = type,
		}
	else
		return {
			span = close(start),
			name = name,
		}
	end
end

local function parse_var_root(): ast.VarRoot
	local start = open()

	local fast_current_kind = current_kind

	if fast_current_kind == "identifier" then
		local name = consume_identifier()

		return {
			kind = "name" :: "name",
			span = close(start),

			name = name,
		}
	elseif fast_current_kind == "(" then
		consume("(")
		local expr = parse_expr()
		expect(")")

		return {
			kind = "paren" :: "paren",
			span = close(start),

			expr = expr,
		}
	else
		return report(`expected variable or expression, but got {display(current_kind, current_span)} instead`)
	end
end

local function parse_table_field(): ast.TableField
	local start = open()

	if current_kind == "identifier" and lookahead_kind == "=" then
		local name = consume_identifier()
		consume("=")
		local value = parse_expr()

		return {
			kind = "namekey" :: "namekey",
			span = close(start),

			name = name,
			value = value,
		}
	elseif current_kind == "[" then
		consume("[")
		local key = parse_expr()
		consume("]")
		consume("=")
		local value = parse_expr()

		return {
			kind = "exprkey" :: "exprkey",
			span = close(start),

			key = key,
			value = value,
		}
	else
		local value = parse_expr()

		return {
			kind = "nokey" :: "nokey",
			span = close(start),

			value = value,
		}
	end
end

local function parse_table(): ast.Table
	local start = open()

	consume("{")
	local fields: { ast.TableField } = {}

	while current_kind ~= "}" do
		push(fields, parse_table_field())

		if current_kind == "," or current_kind == ";" then
			consume()
		else
			break
		end
	end

	expect("}")

	return {
		span = close(start),

		fields = fields,
	}
end

local function parse_function_args(): { ast.Expr }
	if current_kind == "(" then
		consume("(")
		local exprs: { ast.Expr } = {}

		if current_kind ~= ")" then
			while true do
				push(exprs, parse_expr())

				if current_kind == "," then
					consume(",")
				else
					break
				end
			end
		end

		expect(")")
		return exprs
	elseif current_kind == "{" then
		local start = open()
		local table = parse_table()

		return {{
			kind = "table" :: "table",
			span = close(start),
			table = table,
		}}
	elseif current_kind == "string" then
		local start = open()
		local string = consume_string()

		return {{
			kind = "string" :: "string",
			span = close(start),
			string = string,
		}}
	else
		error("incorrect current_kind on parse_function_args")
	end
end

local function parse_var_suffixes(): { ast.VarSuffix }
	local line = #lines
	local suffixes: { ast.VarSuffix } = {}

	while true do
		local start = open()

		local fast_current_kind = current_kind

		if fast_current_kind == "." then
			consume(".")
			local name = expect_identifier()

			push(suffixes, {
				kind = "name" :: "name",
				span = close(start),

				name = name,
			})
		elseif fast_current_kind == "[" then
			consume("[")
			local expr = parse_expr()
			expect("]")

			push(suffixes, {
				kind = "expr" :: "expr",
				span = close(start),

				expr = expr,
			})
		elseif fast_current_kind == "(" and #lines ~= line then
			report("ambiguous syntax: this looks like an argument \z
				list for a function call, but could also be the start \z
				of a new statement; use ';' to separate statements\z
			")
		elseif fast_current_kind == "(" or fast_current_kind == ":"
			or current_kind == "{" or current_kind == "string"
		then
			local method: ast.Identifier? = nil
			if current_kind == ":" then
				consume(":")
				method = consume_identifier()
			end

			local args = parse_function_args()

			push(suffixes, {
				kind = "call" :: "call",
				span = close(start),

				method = method,
				args = args,
			})
		else
			break
		end
	end

	return suffixes
end

function parse_var(): ast.Var
	local start = open()

	local root = parse_var_root()
	local suffixes = parse_var_suffixes()

	return {
		span = close(start),

		root = root,
		suffixes = suffixes,
	}
end

local function parse_complex_istring(): ast.Expr_ComplexIString
	local start = open()

	local segments: { ast.IString } = { consume_istring() }
	local exprs: { ast.Expr } = {}

	while true do
		push(exprs, parse_expr())

		if current_kind == "lastistring" then
			push(segments, consume_istring())
			break
		elseif current_kind == "middleistring" then
			push(segments, consume_istring())
		else
			report(`expected interpolated string segment, but got {display(current_kind, current_span)} instead`)
		end
	end

	return {
		kind = "complexistring" :: "complexistring",
		span = close(start),

		segments = segments,
		exprs = exprs,
	}
end

local function parse_function_attributes(): { ast.Attribute }
	local attributes: { ast.Attribute } = {}

	while current_kind == "attribute" do
		push(attributes, consume_attribute())
	end

	return attributes
end

local function parse_function_body(): ast.FunctionBody
	local start = open()

	local generics = if current_kind == "<" then parse_generic_decl() else nil
	expect("(")

	local params: { ast.Binding } = {}
	local varargs: index<ast.FunctionBody, "varargs"> = nil

	if current_kind ~= ")" then
		while true do
			if current_kind == "..." then
				local varargs_start = open()

				consume("...")
				local type: (ast.Type | ast.GenericTypePack)? = nil

				if current_kind == ":" then
					consume(":")

					if current_kind == "identifier" and lookahead_kind == "..." then
						type = parse_type_pack() :: ast.GenericTypePack
					else
						type = parse_type()
					end
				end

				varargs = {
					span = close(varargs_start),
					type = type,
				}

				break
			end

			push(params, parse_binding())

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end
	end

	expect(")")

	local ret: ast.ReturnType?
	if current_kind == ":" then
		consume(":")
		ret = parse_type_or_type_pack()
	end

	local block = parse_block()
	expect("end")

	return {
		span = close(start),

		generics = generics,
		params = params,
		varargs = varargs,
		ret = ret,
		block = block,
	}
end

local function parse_if_else_expr_branch(): ast.IfElseExprBranch
	local start = open()

	local condition = parse_expr()
	expect("then")
	local body = parse_expr()

	return {
		span = close(start),

		condition = condition,
		body = body,
	}
end

local function parse_if_else_expr(): ast.Expr_IfElse
	local start = open()

	consume("if")
	local branches: { ast.IfElseExprBranch } = {}

	while true do
		push(branches, parse_if_else_expr_branch())

		if current_kind == "elseif" then
			consume("elseif")
		elseif current_kind == "else" then
			consume("else")
			local else_body = parse_expr()

			return {
				kind = "ifelse" :: "ifelse",
				span = close(start),

				branches = branches,
				else_body = else_body,
			}
		end
	end
end

local function parse_simple_expr(): ast.Expr
	local start = open()

	local fast_current_kind = current_kind

	if fast_current_kind == "nil" then
		consume("nil")
		return {
			kind = "nil" :: "nil",
			span = close(start),
		}
	elseif fast_current_kind == "true" then
		consume("true")
		return {
			kind = "boolean" :: "boolean",
			span = close(start),

			value = true,
		}
	elseif fast_current_kind == "false" then
		consume("false")
		return {
			kind = "boolean" :: "boolean",
			span = close(start),

			value = false,
		}
	elseif fast_current_kind == "number" then
		local number = consume_number()
		return {
			kind = "number" :: "number",
			span = close(start),

			number = number,
		}
	elseif fast_current_kind == "string" then
		local string = consume_string()
		return {
			kind = "string" :: "string",
			span = close(start),

			string = string,
		}
	elseif fast_current_kind == "..." then
		consume("...")
		return {
			kind = "vararg" :: "vararg",
			span = close(start),
		}
	elseif fast_current_kind == "simpleistring" then
		local string = consume_istring()
		return {
			kind = "simpleistring" :: "simpleistring",
			span = close(start),

			string = string,
		}
	elseif fast_current_kind == "firstistring" then
		return parse_complex_istring()
	elseif fast_current_kind == "{" then
		local table = parse_table()
		return {
			kind = "table" :: "table",
			span = close(start),

			table = table,
		}
	elseif fast_current_kind == "function" then
		consume("function")
		local body = parse_function_body()

		return {
			kind = "function" :: "function",
			span = close(start),

			attributes = {},
			body = body,
		}
	elseif fast_current_kind == "attribute" then
		local attributes = parse_function_attributes()
		expect("function")
		local body = parse_function_body()

		return {
			kind = "function" :: "function",
			span = close(start),

			attributes = attributes,
			body = body,
		}
	elseif fast_current_kind == "if" then
		return parse_if_else_expr()
	else
		local var = parse_var()
		return {
			kind = "var" :: "var",
			span = close(start),

			var = var,
		}
	end
end

local function parse_unary_operator(): ast.UnaryOperator?
	if current_kind == "-" or current_kind == "#" or current_kind == "not" then
		local operator = { kind = current_kind, span = current_span } :: ast.UnaryOperator
		consume()

		return operator
	else
		return nil
	end
end

local binary_operators = {
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["//"] = true,
	["%"] = true,
	["^"] = true,
	[".."] = true,
	["<"] = true,
	["<="] = true,
	[">"] = true,
	[">="] = true,
	["=="] = true,
	["~="] = true,
	["and"] = true,
	["or"] = true,
}

local function is_binary_operator(): boolean?
	return binary_operators[current_kind]
end

local function binary_operator_priority(): (number, number)
	if current_kind == "+" or current_kind == "-" then
		return 6, 6
	elseif current_kind == "*" or current_kind == "/" or current_kind == "//" or current_kind == "%" then
		return 7, 7
	elseif current_kind == "^" then
		return 10, 9
	elseif current_kind == ".." then
		return 5, 4
	elseif current_kind == "==" or current_kind == "~=" then
		return 3, 3
	elseif current_kind == "<" or current_kind == "<=" or current_kind == ">" or current_kind == ">=" then
		return 3, 3
	elseif current_kind == "and" then
		return 2, 2
	elseif current_kind == "or" then
		return 1, 1
	else
		error("unreachable")
	end
end

local function parse_expr_with_limit(limit: number): ast.Expr
	local start = open()

	local expr: ast.Expr

	local unop = parse_unary_operator()
	if unop then
		local rhs = parse_expr_with_limit(8)

		expr = {
			kind = "unary" :: "unary",
			span = close(start),

			operator = unop,
			expr = rhs,
		}
	else
		expr = parse_simple_expr()

		if current_kind == "::" then
			consume("::")
			local type = parse_type()

			expr = {
				kind = "assertion" :: "assertion",
				span = close(start),

				expr = expr,
				type = type,
			}
		end
	end

	while true do
		local binop = is_binary_operator()

		if not binop then
			break
		end

		local left_priority, right_priority = binary_operator_priority()
		if left_priority < limit then
			break
		end

		binop = { kind = current_kind, span = current_span } :: ast.BinaryOperator
		consume()

		local right = parse_expr_with_limit(right_priority)

		expr = {
			kind = "binary" :: "binary",
			span = close(start),

			left = expr,
			operator = binop,
			right = right,
		}
	end

	return expr
end

function parse_expr()
	return parse_expr_with_limit(0)
end

local function parse_local_variable_stat(): ast.Stat_LocalVariable
	local start = open()

	consume("local")
	local bindings: { ast.Binding } = {}

	while true do
		push(bindings, parse_binding())

		if current_kind == "," then
			consume(",")
		else
			break
		end
	end

	if current_kind == "=" then
		consume("=")
		local exprs: { ast.Expr } = {}

		while true do
			push(exprs, parse_expr())

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end

		return {
			kind = "localvariable" :: "localvariable",
			span = close(start),

			bindings = bindings,
			exprs = exprs,
		}
	else
		return {
			kind = "localvariable" :: "localvariable",
			span = close(start),

			bindings = bindings,
		}
	end
end

local function parse_local_function_stat(start: number, attributes: { ast.Attribute }): ast.Stat_LocalFunction
	consume("local")
	consume("function")

	local name = expect_identifier()
	local body = parse_function_body()

	return {
		kind = "localfunction" :: "localfunction",
		span = close(start),

		attributes = attributes,
		name = name,
		body = body,
	}
end

local function parse_if_stat_branch(): ast.IfStatBranch
	local start = open()

	local condition = parse_expr()
	expect("then")
	local block = parse_block()

	return {
		span = close(start),

		condition = condition,
		block = block,
	}
end

local function parse_if_stat(): ast.Stat_If
	local start = open()

	consume("if")
	local branches: { ast.IfStatBranch } = {}

	while true do
		push(branches, parse_if_stat_branch())

		if current_kind == "elseif" then
			consume("elseif")
		elseif current_kind == "else" then
			consume("else")
			local else_block = parse_block()
			expect("end")

			return {
				kind = "if" :: "if",
				span = close(start),

				branches = branches,
				else_block = else_block,
			}
		elseif current_kind == "end" then
			consume("end")

			return {
				kind = "if" :: "if",
				span = close(start),

				branches = branches,
			}
		else
			report(`expected one of 'elseif', 'else', or 'end' but got {display(current_kind, current_span)} instead`)
		end
	end
end

local function parse_for_stat(): ast.Stat_GenericFor | ast.Stat_NumericFor
	local start = open()

	consume("for")
	local binding = parse_binding()

	if current_kind == "=" then
		consume("=")
		local start_expr = parse_expr()
		expect(",")
		local end_expr = parse_expr()

		local step_expr: ast.Expr?
		if current_kind == "," then
			consume(",")
			step_expr = parse_expr()
		end

		expect("do")
		local block = parse_block()
		expect("end")

		return {
			kind = "numericfor" :: "numericfor",
			span = close(start),

			binding = binding,
			start_expr = start_expr,
			end_expr = end_expr,
			step_expr = step_expr,
			block = block,
		}
	else
		local bindings: { ast.Binding } = { binding }
		while current_kind == "," do
			consume(",")
			push(bindings, parse_binding())
		end

		expect("in")

		local exprs: { ast.Expr } = { parse_expr() }
		while current_kind == "," do
			consume(",")
			push(exprs, parse_expr())
		end

		expect("do")
		local block = parse_block()
		expect("end")

		return {
			kind = "genericfor" :: "genericfor",
			span = close(start),

			bindings = bindings,
			exprs = exprs,
			block = block,
		}
	end
end

local function parse_while_stat(): ast.Stat_While
	local start = open()

	consume("while")
	local condition = parse_expr()
	expect("do")
	local block = parse_block()
	expect("end")

	return {
		kind = "while" :: "while",
		span = close(start),

		condition = condition,
		block = block,
	}
end

local function is_block_end(): boolean
	return current_kind == "end"
		or current_kind == "else"
		or current_kind == "elseif"
		or current_kind == "until"
		or current_kind == "eof"
end

local function parse_return_stat(): ast.LastStat_Return
	local start = open()

	consume("return")
	local exprs: { ast.Expr } = {}

	if not is_block_end() and current_kind ~= ";" then
		while true do
			push(exprs, parse_expr())

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end
	end

	return {
		kind = "return" :: "return",
		span = close(start),

		exprs = exprs,
	}
end

local function parse_break_stat(): ast.LastStat_Break
	local span = current_span
	consume("break")

	return {
		kind = "break" :: "break",
		span = span,
	}
end

local function parse_repeat_stat(): ast.Stat_Repeat
	local start = open()

	consume("repeat")
	local block = parse_block()
	expect("until")
	local condition = parse_expr()

	return {
		kind = "repeat" :: "repeat",
		span = close(start),

		block = block,
		condition = condition,
	}
end

local function parse_function_stat(start: number, attributes: { ast.Attribute }): ast.Stat_Function
	consume("function")

	local names = { expect_identifier() }
	while current_kind == "." do
		consume(".")
		push(names, expect_identifier())
	end

	local method: ast.Identifier?
	if current_kind == ":" then
		consume(":")
		method = expect_identifier()
	end

	local body = parse_function_body()

	return {
		kind = "function" :: "function",
		span = close(start),

		attributes = attributes,
		names = names,
		method = method,
		body = body,
	}
end

local function parse_do_stat(): ast.Stat_Do
	local start = open()

	consume("do")
	local block = parse_block()
	expect("end")

	return {
		kind = "do" :: "do",
		span = close(start),

		block = block,
	}
end

local function is_compound_operator(): boolean
	return current_kind == "+="
		or current_kind == "-="
		or current_kind == "/="
		or current_kind == "//="
		or current_kind == "%="
		or current_kind == "^="
		or current_kind == "..="
end

local function parse_type_stat(start: number, export: boolean): ast.Stat_Type
	local name = consume_identifier()
	local generics = if current_kind == "<" then parse_generic_decl_with_defaults() else nil
	expect("=")
	local type = parse_type()

	return {
		kind = "type" :: "type",
		span = close(start),

		export = export,
		name = name,
		generics = generics,
		type = type,
	}
end

local function parse_type_function_stat(start: number, export: boolean): ast.Stat_TypeFunction
	consume("function")
	local name = consume_identifier()
	local body = parse_function_body()

	return {
		kind = "typefunction" :: "typefunction",
		span = close(start),

		export = export,
		name = name,
		body = body,
	}
end

local function parse_stat(): ast.Stat | ast.LastStat
	local fast_current_kind = current_kind

	if fast_current_kind == "local" then
		if lookahead_kind == "function" then
			return parse_local_function_stat(open(), {})
		else
			return parse_local_variable_stat()
		end
	elseif fast_current_kind == "if" then
		return parse_if_stat()
	elseif fast_current_kind == "for" then
		return parse_for_stat()
	elseif fast_current_kind == "while" then
		return parse_while_stat()
	elseif fast_current_kind == "return" then
		return parse_return_stat()
	elseif fast_current_kind == "break" then
		return parse_break_stat()
	elseif fast_current_kind == "repeat" then
		return parse_repeat_stat()
	elseif fast_current_kind == "function" then
		return parse_function_stat(open(), {})
	elseif fast_current_kind == "do" then
		return parse_do_stat()
	elseif fast_current_kind == "attribute" then
		local start = open()
		local attributes = parse_function_attributes()

		if current_kind == "local" then
			return parse_local_function_stat(start, attributes)
		elseif current_kind == "function" then
			return parse_function_stat(start, attributes)
		else
			return report(`\z
				expected function or local function after \z
				function attributes, but got {display(current_kind, current_span)} instead\z
			`)
		end
	end

	local start = open()

	local var = parse_var()
	local last = var.suffixes[#var.suffixes]

	if is_compound_operator() then
		local operator = { kind = current_kind, span = current_span } :: ast.CompoundOperator
		consume()
		local right = parse_expr()

		return {
			kind = "compoundassign" :: "compoundassign",
			span = close(start),

			left = var,
			operator = operator,
			right = right,
		}
	elseif last and last.kind == "call" then
		return {
			kind = "call" :: "call",
			span = close(start),

			call = var,
		}
	elseif current_kind == "=" or current_kind == "," then
		local left = { var }

		while current_kind == "," do
			consume(",")
			push(left, parse_var())
		end

		expect("=")
		local right: { ast.Expr } = {}

		while true do
			push(right, parse_expr())

			if current_kind == "," then
				consume(",")
			else
				break
			end
		end

		return {
			kind = "assign" :: "assign",
			span = close(start),

			left = left,
			right = right,
		}
	elseif not last and var.root.kind == "name" then
		local text = buffer.readstring(source, var.span.x, var.span.y - var.span.x)

		if text == "export" or text == "type" then
			local export = text == "export"
			if export then
				text = buffer.readstring(source, current_span.x, current_span.y - current_span.x)

				if text == "type" then
					consume("identifier")
				else
					report(`expected 'type' after 'export', but got {display(current_kind, current_span)} instead`)
				end
			end

			if current_kind == "identifier" then
				return parse_type_stat(start, export)
			elseif current_kind :: any == "function" then
				return parse_type_function_stat(start, export)
			else
				return report(`expected identifier or 'function' after 'export type', but got {display(current_kind, current_span)} instead`)
			end
		elseif text == "continue" then
			return {
				kind = "continue" :: "continue",
				span = close(start),
			}
		end
	end

	return report("incomplete statement: expected assignment or function call")
end

function parse_block(): ast.Block
	local start = open()
	local stats: { ast.Stat } = {}

	while not is_block_end() do
		local stat = parse_stat()

		if stat.kind == "return" or stat.kind == "break" or stat.kind == "continue" then
			return {
				span = close(start),

				stats = stats,
				last_stat = stat,
			}
		else
			push(stats, stat)
		end
	end

	return {
		span = close(start),

		stats = stats,
	}
end

local function parse_chunk(): ast.Chunk
	local block = parse_block()
	expect("eof")

	return block
end

local function safe<T>(input: string | buffer, parser: () -> T): { success: true, result: T } | { success: false, result: Error }
	load(if type(input) == "string" then buffer.fromstring(input) else input, 0)
	local success, result = pcall(parser)
	return { success = success, result = result } :: any
end

return {
	parse_type = parse_type,
	parse_table = parse_table,
	parse_expr = parse_expr,
	parse_block = parse_block,
	parse_chunk = parse_chunk,

	safe = safe,
}