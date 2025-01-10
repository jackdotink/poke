--!optimize 2
local cst = require("./cst")
local opt = require("./opt")

local function unreachable(_: never): never
	error("unreachable")
end

type Error = {
	message: string,
	span: cst.Span,
}

local buf: buffer

local lines: { number }

local current: string
local current_span: cst.Span
local current_trivia: { cst.Trivia }

local lookahead: string
local lookahead_span: cst.Span
local lookahead_trivia: { cst.Trivia }

local lex: () -> ()
local load: (code: string) -> ()

do
	local sid: number
	local pos: number
	local len: number

	local brace_count: number
	local brace_stack: { number } = {}

	local function byte(c: string): number
		return string.byte(c) :: number
	end

	local function peek(): number
		return (buffer.readu8(buf, pos))
	end

	local function bump()
		if pos ~= len then
			pos += 1
		end
	end

	local function bump_any()
		if peek() == byte("\n") then
			table.insert(lines, pos + 1)
		end

		bump()
	end

	local function bump_peek(): number
		bump()
		return (peek())
	end

	local function is_whitespace(c: number): boolean
		return c == byte(" ") or c == byte("\t") or c == byte("\n") or c == byte("\r")
	end

	local function is_digit(c: number): boolean
		return byte("0") <= c and c <= byte("9")
	end

	local function is_alpha(c: number): boolean
		return (byte("a") <= c and c <= byte("z")) or (byte("A") <= c and c <= byte("Z"))
	end

	local function number(): "number" | "error"
		local had_underscore = false
		local start = pos
		local base = 10

		local c = peek()

		if c == byte("0") then
			c = bump_peek()

			if c == byte("x") or c == byte("X") then
				c = bump_peek()
				base = 16
			elseif c == byte("b") or c == byte("B") then
				c = bump_peek()
				base = 2
			end
		end

		while is_digit(c) or c == byte(".") or c == byte("_") do
			c = bump_peek()

			if c == byte("_") then
				had_underscore = true
			end
		end

		if c == byte("e") or c == byte("E") then
			c = bump_peek()

			if c == byte("+") or c == byte("-") then
				c = bump_peek()
			end
		end

		while is_digit(c) or is_alpha(c :: any) or c == byte("_") do
			c = bump_peek()
		end

		local text: string
		if base == 10 then
			text = buffer.readstring(buf, start, pos - start) :: string
		else
			text = buffer.readstring(buf, start + 2, pos - start - 2) :: string
		end

		text = string.gsub(text, "_", "")

		if tonumber(text, base) then
			return "number"
		else
			return "error"
		end
	end

	local function string_backslash()
		local c = peek()

		if c == byte("\r") then
			c = bump_peek()

			if c == byte("\n") then
				table.insert(lines, pos + 1)
				bump()
			end
		elseif c == byte("z") then
			bump()

			while is_whitespace(peek()) do
				bump_any()
			end
		else
			bump_any()
		end
	end

	local function quoted_string(): "string" | "error"
		local delim = peek()
		local c = bump_peek()

		while c ~= delim do
			if c == 0 or c == byte("\n") or c == byte("\r") then
				return "error"
			elseif c == byte("\\") then
				bump()
				string_backslash()
			else
				bump()
			end

			c = peek()
		end

		bump()
		return "string"
	end

	local function long_seperator(): number
		local count = 0

		while peek() == byte("=") do
			bump()
			count += 1
		end
		
		return count
	end

	local function long_string(eqs: number): "string" | "error"
		bump()

		while true do
			local c = peek()

			if c == byte("]") then
				bump()

				if long_seperator() == eqs and peek() == byte("]") then
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
	): "istring_simple" | "istring_first" | "istring_middle" | "istring_last" | "error"
		local c = peek()

		while c ~= byte("`") do
			if c == 0 or c == byte("\n") or c == byte("\r") then
				return "error"
			elseif c == byte("\\") then
				bump()

				if peek() == byte("u") then
					bump()

					if peek() == byte("{") then
						bump()
					end
				else
					string_backslash()
				end
			elseif c == byte("{") then
				bump()

				if peek() == byte("{") then
					bump()
					return "error"
				else
					table.insert(brace_stack, brace_count)

					if from == "start" then
						return "istring_first"
					else
						return "istring_middle"
					end
				end
			else
				bump()
			end

			c = peek()
		end

		bump()

		if from == "start" then
			return "istring_simple"
		else
			return "istring_last"
		end
	end

	local function comment(): "comment" | "error"
		local c = peek()

		if c == byte("[") then
			bump()
			local eqs = long_seperator()

			if peek() == byte("[") then
				local result = long_string(eqs)

				if result == "error" then
					return "error"
				else
					return "comment"
				end
			end
		end

		c = peek()

		while c ~= 0 and c ~= byte("\n") do
			c = bump_peek()
		end

		return "comment"
	end

	local function next(): string
		local c = peek()

		if is_whitespace(c) then
			repeat
				bump_any()
			until not is_whitespace(peek())

			return "whitespace"
		elseif is_alpha(c :: number) or c == byte("_") then
			local start = pos
			local first = c

			repeat
				c = bump_peek()
			until not (is_alpha(c :: any) or is_digit(c :: any) or c == byte("_"))

			if first == byte("l") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "local" then text else "identifier"
			elseif first == byte("e") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "end" or text == "elseif" or text == "else" then text else "identifier"
			elseif first == byte("t") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "then" or text == "true" then text else "identifier"
			elseif first == byte("r") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "return" or text == "repeat" then text else "identifier"
			elseif first == byte("f") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "function" or text == "for" or text == "false" then text else "identifier"
			elseif first == byte("i") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "if" or text == "in" then text else "identifier"
			elseif first == byte("d") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "do" then text else "identifier"
			elseif first == byte("n") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "nil" or text == "not" then text else "identifier"
			elseif first == byte("o") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "or" then text else "identifier"
			elseif first == byte("a") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "and" then text else "identifier"
			elseif first == byte("b") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "break" then text else "identifier"
			elseif first == byte("w") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "while" then text else "identifier"
			elseif first == byte("u") then
				local text = buffer.readstring(buf, start, pos - start) :: string
				return if text == "until" then text else "identifier"
			else
				return "identifier"
			end
		elseif is_digit(c :: number) then
			return number()
		elseif c == byte("'") or c == byte('"') then
			return quoted_string()
		elseif c == byte("`") then
			bump()
			return istring_section("start")
		elseif c == byte("{") then
			brace_count += 1
			bump()
			return "{"
		elseif c == byte("}") then
			local brace_stack_len = #brace_stack

			if brace_stack_len ~= 0 and brace_stack[brace_stack_len] == brace_count then
				brace_stack[brace_stack_len] = nil :: any
				return istring_section("middle")
			else
				brace_count -= 1
				bump()
				return "}"
			end
		elseif c == byte("[") then
			bump()

			local eqs = long_seperator()

			if peek() == byte("[") then
				return long_string(eqs)
			elseif eqs ~= 0 then
				return "error"
			else
				return "["
			end
		elseif c == byte("-") then
			c = bump_peek()

			if c == byte(">") then
				bump()
				return "->"
			elseif c == byte("=") then
				bump()
				return "-="
			elseif c == byte("-") then
				bump()
				return comment()
			else
				return "-"
			end
		end

		bump()
		if c == byte(",") then
			return ","
		elseif c == byte("(") then
			return "("
		elseif c == byte(")") then
			return ")"
		elseif c == byte("=") then
			c = peek()

			if c == byte("=") then
				bump()
				return "=="
			else
				return "="
			end
		elseif c == byte(".") then
			c = peek()

			if c == byte(".") then
				c = bump_peek()

				if c == byte(".") then
					bump()
					return "..."
				elseif c == byte("=") then
					bump()
					return "..="
				else
					return ".."
				end
			elseif is_digit(c) then
				pos -= 1
				return number()
			else
				return "."
			end
		elseif c == byte(":") then
			c = peek()

			if c == byte(":") then
				bump()
				return "::"
			else
				return ":"
			end
		elseif c == byte(">") then
			c = peek()

			if c == byte("=") then
				bump()
				return ">="
			else
				return ">"
			end
		elseif c == byte("<") then
			c = peek()

			if c == byte("=") then
				bump()
				return "<="
			else
				return "<"
			end
		elseif c == byte("]") then
			return "]"
		elseif c == byte("|") then
			return "|"
		elseif c == byte("?") then
			return "?"
		elseif c == byte("+") then
			c = peek()

			if c == byte("=") then
				bump()
				return "+="
			else
				return "+"
			end
		elseif c == byte("*") then
			c = peek()

			if c == byte("=") then
				bump()
				return "*="
			else
				return "*"
			end
		elseif c == byte("#") then
			return "#"
		elseif c == byte("&") then
			return "&"
		elseif c == byte("~") then
			c = peek()

			if c == byte("=") then
				bump()
				return "~="
			else
				return "error"
			end
		elseif c == byte("^") then
			c = peek()

			if c == byte("=") then
				bump()
				return "^="
			else
				return "^"
			end
		elseif c == byte("/") then
			c = peek()

			if c == byte("/") then
				c = bump_peek()

				if c == byte("=") then
					bump()
					return "//="
				else
					return "//"
				end
			elseif c == byte("=") then
				bump()
				return "/="
			else
				return "/"
			end
		elseif c == byte(";") then
			return ";"
		elseif c == byte("%") then
			c = peek()

			if c == byte("=") then
				bump()
				return "%="
			else
				return "%"
			end
		elseif c == 0 then
			return "eof"
		end

		return "error"
	end

	local function lex_with_trivia()
		local trivia: { cst.Trivia } = {}

		while true do
			local start = pos
			local kind = next()

			if kind == "whitespace" or kind == "comment" then
				table.insert(trivia, {
					kind = kind,
					span = vector.create(start, pos, sid),
				})
			else
				lookahead = kind
				lookahead_span = vector.create(start, pos, sid)
				lookahead_trivia = trivia

				return
			end
		end
	end

	local function lex_without_trivia()
		while true do
			local start = pos
			local kind = next()

			if kind ~= "whitespace" and kind ~= "comment" then
				lookahead = kind
				lookahead_span = vector.create(start, pos, sid)

				return
			end
		end
	end

	function load(code: string, srcid: number)
		sid = srcid

		len = #code + 1
		pos = 0

		buf = buffer.create(len)
		buffer.writestring(buf, 0, code, len - 1)

		brace_count = 0
		table.clear(brace_stack)

		lines = { 1 }

		if opt.trivia then
			lex = lex_with_trivia
		else
			lex = lex_without_trivia
		end

		lex()

		current = lookahead
		current_span = lookahead_span
		current_trivia = lookahead_trivia

		lex()
	end
end

local function display(kind: string, span: cst.Span): string
	span = span :: any
	
	if
		kind == "ident"
		or kind == "number"
		or kind == "string"
		or kind == "attribute"
	then
		return kind
	elseif kind == "error" then
		return "'" .. buffer.readstring(buf, span.x, span.y - span.x) .. "'"
	else
		return "'" .. kind .. "'"
	end
end

local function report(message: string, span: cst.Span?): never
	local report: Error = {
		message = message,
		span = span or current_span,
	}

	error(report)
end

local expect_failure
function expect_failure(kind: string): never
	return report(`expected {display(kind, vector.create(0, 0, 0))}, but got {display(current, current_span)} instead`)
end

local function consume_atom<Kind>(): cst.Atom<Kind>
	local atom = {
		kind = current,
		span = current_span,
		trivia = current_trivia,
	}

	current = lookahead
	current_span = lookahead_span
	current_trivia = lookahead_trivia

	lex()

	return atom
end

local function consume_atom_identifier<Kind>(kind: string): cst.Atom<Kind>
	current = kind
	return consume_atom()
end

local function expect_atom<Kind>(kind: Kind): cst.Atom<Kind>
	if current == kind :: any then
		return consume_atom() :: any
	else
		return (expect_failure(kind :: any))
	end
end

local function consume_identifier(): cst.Identifier
	local identifier = {
		span = current_span,
		trivia = current_trivia,
	}

	current = lookahead
	current_span = lookahead_span
	current_trivia = lookahead_trivia
	
	lex()

	return identifier :: cst.Identifier
end

local function expect_identifier(): cst.Identifier
	if current == "identifier" then
		return consume_identifier()
	else
		return (expect_failure("identifier"))
	end
end

local function consume_number(): cst.Number
	local number = {
		span = current_span,
		trivia = current_trivia,
	}

	current = lookahead
	current_span = lookahead_span
	current_trivia = lookahead_trivia

	lex()

	return number :: cst.Number
end

local function consume_string(): cst.String
	local string = {
		span = current_span,
		trivia = current_trivia,
	}

	current = lookahead
	current_span = lookahead_span
	current_trivia = lookahead_trivia

	lex()

	return string :: cst.String
end

local function consume_attribute(): cst.Attribute
	local attribute = {
		span = current_span,
		trivia = current_trivia,
	}

	current = lookahead
	current_span = lookahead_span
	current_trivia = lookahead_trivia

	lex()

	return attribute :: cst.Attribute
end

local parse_type: () -> cst.Type
local parse_return_type: () -> cst.ReturnType
local parse_generic_decl: () -> cst.GenericDecl
local parse_generic_decl_with_defaults: () -> cst.GenericDeclWithDefaults
local parse_var: () -> cst.Var
local parse_expr: () -> cst.Expr
local parse_table: () -> cst.Table
local parse_block: () -> cst.Block

do
	local parse_simple_type: (allow_list_pack: boolean) -> cst.Type | cst.ListTypePack
	local parse_type_suffix: (type: cst.Type) -> cst.Type
	local parse_tail_type: () -> cst.TailType

	local function parse_function_type_params(): (index<cst.Type_Function, "params">, cst.TailType?)
		local params: index<cst.Type_Function, "params"> = {}

		while true do
			if
				current == "..."
				or (current == "identifier" and lookahead == "...")
			then
				local pack = parse_tail_type()
				return params, pack
			end

			local name: {
				name: cst.Identifier,
				colon: cst.Atom<":">,
			}? = nil

			if current == "identifier" and lookahead == ":" then
				name = {
					name = consume_identifier(),
					colon = consume_atom() :: cst.Atom<":">,
				}
			end

			local type = parse_type()

			if current == "," then
				params[#params + 1] = {
					node = { name = name, type = type },
					sep = consume_atom() :: cst.Atom<",">?,
				}
			else
				params[#params + 1] = {
					node = { name = name, type = type },
					sep = nil :: cst.Atom<",">?,
				}
			end
		end
	end

	function parse_generic_decl(): cst.GenericDecl
		local open = expect_atom("<") :: cst.Atom<"<">
		local names: index<cst.GenericDecl, "names"> = {}
		local packs: index<cst.GenericDecl, "packs"> = {}

		while true do
			if current == "identifier" and lookahead == "..." then
				break
			end

			local name = expect_identifier()
			
			if current == "," then
				names[#names + 1] = {
					node = name,
					sep = consume_atom() :: cst.Atom<",">?,
				}
			else
				names[#names + 1] = {
					node = name,
					sep = nil :: cst.Atom<",">?,
				}

				return {
					angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },
					names = names,
					packs = packs,
				}
			end
		end

		while true do
			local name = expect_identifier()
			local dots = expect_atom("...") :: cst.Atom<"...">

			if current == "," then
				packs[#packs + 1] = {
					node = { name = name, dots = dots },
					sep = consume_atom() :: cst.Atom<",">?,
				}
			else
				packs[#packs + 1] = {
					node = { name = name, dots = dots },
					sep = nil :: cst.Atom<",">?,
				}

				return {
					angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },
					names = names,
					packs = packs,
				}
			end
		end
	end

	function parse_generic_decl_with_defaults(): cst.GenericDeclWithDefaults
		local open = expect_atom("<") :: cst.Atom<"<">
		local names_without_defaults: index<cst.GenericDeclWithDefaults, "names_without_defaults"> = {}
		local names_with_defaults: index<cst.GenericDeclWithDefaults, "names_with_defaults"> = {}
		local packs_without_defaults: index<cst.GenericDeclWithDefaults, "packs_without_defaults"> = {}
		local packs_with_defaults: index<cst.GenericDeclWithDefaults, "packs_with_defaults"> = {}

		local had_default = false

		while true do
			if current == "identifier" and lookahead == "..." then
				break
			end

			local name = expect_identifier()

			if had_default or current == "=" then
				had_default = true

				local equals = expect_atom("=") :: cst.Atom<"=">
				local default = parse_type()

				if current == "," then
					names_with_defaults[#names_with_defaults + 1] = {
						node = { name = name, equals = equals, default = default },
						sep = consume_atom(",") :: cst.Atom<",">?,
					}
				else
					names_with_defaults[#names_with_defaults + 1] = {
						node = { name = name, equals = equals, default = default },
						sep = nil :: cst.Atom<",">?,
					}

					return {
						angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },

						names_without_defaults = names_without_defaults,
						names_with_defaults = names_with_defaults,
						packs_without_defaults = packs_without_defaults,
						packs_with_defaults = packs_with_defaults,
					}
				end
			else
				if current == "," then
					names_without_defaults[#names_with_defaults + 1] = {
						node = name,
						sep = consume_atom() :: cst.Atom<",">?,
					}
				else
					names_without_defaults[#names_with_defaults + 1] = {
						node = name,
						sep = nil :: cst.Atom<",">?,
					}

					return {
						angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },

						names_without_defaults = names_without_defaults,
						names_with_defaults = names_with_defaults,
						packs_without_defaults = packs_without_defaults,
						packs_with_defaults = packs_with_defaults,
					}
				end
			end
		end

		while true do
			local name = expect_identifier()
			local dots = expect_atom("...") :: cst.Atom<"...">

			if had_default or current == "=" then
				local equals = expect_atom("=") :: cst.Atom<"=">
				local default: cst.TypePack

				if
					current == "..."
					or (current == "identifier" and lookahead == "...")
				then
					default = parse_tail_type()
				elseif current == "(" then
					local maybe_pack = parse_simple_type(true)

					if maybe_pack.kind == "list" then
						default = maybe_pack
					elseif maybe_pack.kind == "function" then
						report("expected type pack after '=', found function type", vector.zero --[[TODO: span of function type]])
					else
						error("internal: parse_simple_type did not return a list or function type at '(' token")
					end
				else
					report(`expected type pack after '=', found {display(current, current_span)}`)
				end

				if current == "," then
					packs_with_defaults[#packs_with_defaults + 1] = {
						node = { name = name, dots = dots, equals = equals, default = default },
						sep = consume_atom() :: cst.Atom<",">?,
					}
				else
					packs_with_defaults[#packs_with_defaults + 1] = {
						node = { name = name, dots = dots, equals = equals, default = default },
						sep = nil :: cst.Atom<",">?,
					}

					return {
						angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },

						names_without_defaults = names_without_defaults,
						names_with_defaults = names_with_defaults,
						packs_without_defaults = packs_without_defaults,
						packs_with_defaults = packs_with_defaults,
					}
				end
			else
				if current == "," then
					packs_without_defaults[#packs_without_defaults + 1] = {
						node = { name = name, dots = dots },
						sep = consume_atom() :: cst.Atom<",">?,
					}
				else
					packs_without_defaults[#packs_without_defaults + 1] = {
						node = { name = name, dots = dots },
						sep = nil :: cst.Atom<",">?,
					}

					return {
						angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },

						names_without_defaults = names_without_defaults,
						names_with_defaults = names_with_defaults,
						packs_without_defaults = packs_without_defaults,
						packs_with_defaults = packs_with_defaults,
					}
				end
			end
		end
	end

	function parse_simple_type(allow_list_pack: boolean): cst.Type | cst.ListTypePack
		if current == "nil" then
			return {
				kind = "nil",
				token = consume_atom() :: cst.Atom<"nil">,
			}
		elseif current == "true" or current == "false" then
			return {
				kind = "boolean",
				token = consume_atom() :: cst.Atom<"true"> | cst.Atom<"false">,
			}
		elseif current == "string" then
			return {
				kind = "string" :: "string",
				token = consume_string(),
			}
		elseif current == "identifier" then
			local text = buffer.readstring(buf, current_span.x, current_span.y)

			if text == "typeof" then
				local typeof_tok = consume_atom_identifier("typeof") :: cst.Atom<"typeof">
				local open = expect_atom("(") :: cst.Atom<"(">
				local expr = parse_expr()
				local close = expect_atom(")") :: cst.Atom<")">

				return {
					kind = "typeof",
					typeof_tok = typeof_tok,
					parens = { open = open, close = close },
					expr = expr,
				}
			end

			local name = consume_identifier()
			local prefix: index<cst.Type_Reference, "prefix"> = nil

			if current == "." then
				prefix = { name = name, dot = consume_atom() :: cst.Atom<"."> }
				name = expect_identifier()
			elseif current == "..." then
				report("unexpected '...' after type name; type pack is not allowed in this context")
			end

			if current == "<" then
				local open = consume_atom() :: cst.Atom<"<">
				local types: cst.Separated<cst.TypeArg, cst.Atom<",">> = {}

				if current == ">" then
					return {
						kind = "reference",
						prefix = prefix,
						name = name,
						generics = {
							angles = { open = open, close = consume_atom() :: cst.Atom<">"> },
							types = types,
						} :: index<cst.Type_Reference, "generics">,
					}
				else
					while true do
						local generic: cst.TypeArg

						if
							current == "..."
							or (current == "identifier" and lookahead == "...")
						then
							generic = parse_tail_type()
						elseif current == "(" then
							local type = parse_simple_type(true)

							if type.kind == "list" then
								generic = type
							else
								generic = parse_type_suffix(type)
							end
						else
							generic = parse_type()
						end

						if current == "," then
							table.insert(types, {
								node = generic,
								sep = consume_atom() :: cst.Atom<",">,
							})
						else
							table.insert(types, {
								node = generic,
								sep = nil :: cst.Atom<",">?,
							})

							return {
								kind = "reference",
								prefix = prefix,
								name = name,
								generics = {
									angles = { open = open, close = expect_atom(">") :: cst.Atom<">"> },
									types = types,
								} :: index<cst.Type_Reference, "generics">,
							}
						end
					end
				end
			else
				return {
					kind = "reference",
					prefix = prefix,
					name = name,
					generics = nil,
				}
			end
		elseif current == "{" then
			local open = consume_atom() :: cst.Atom<"{">
			
			local had_indexer = false
			local fields: index<cst.Type_Table, "fields"> = {}

			while current ~= "}" do
				local access: cst.Atom<"read"> | cst.Atom<"write"> | nil = nil
				local field: cst.TableTypeField

				if current == "identifier" and lookahead ~= ":" then
					local text = buffer.readstring(buf, current_span.x, current_span.y)

					if text == "read" or text == "write" then
						access = consume_atom_identifier(text) :: cst.Atom<"read"> | cst.Atom<"write">
					end
				end

				if current == "[" then
					if lookahead == "string" then
						local open = consume_atom() :: cst.Atom<"[">
						local key = consume_string()
						local close = expect_atom("]") :: cst.Atom<"]">
						local colon = expect_atom(":") :: cst.Atom<":">
						local type = parse_type()

						field = {
							kind = "stringprop",
							access = access,
							bracks = { open = open, close = close },
							key = key,
							colon = colon,
							type = type,
						} :: cst.TableTypeField_StringProp
					else
						local open = consume_atom() :: cst.Atom<"[">
						local key = parse_type()
						local close = expect_atom("]") :: cst.Atom<"]">
						local colon = expect_atom(":") :: cst.Atom<":">
						local type = parse_type()

						field = {
							kind = "indexer",
							access = access,
							bracks = { open = open, close = close },
							key = key,
							colon = colon,
							type = type,
						} :: cst.TableTypeField_Indexer

						if had_indexer then
							report("table types cannot have more than one indexer", vector.zero --[[TODO: span of field]])
						else
							had_indexer = true
						end
					end
				elseif current == "identifier" and lookahead == ":" then
					local name = consume_identifier()
					local colon = consume_atom() :: cst.Atom<":">
					local type = parse_type()

					field = {
						kind = "nameprop",
						access = access,
						name = name,
						colon = colon,
						type = type,
					}
				elseif #fields == 0 then
					local type = parse_type()
					local close = expect_atom("}") :: cst.Atom<"}">

					if access ~= nil then
						report("access modifier is illegal in this position", access.span)
					end

					return {
						kind = "array",
						braces = { open = open, close = close },
						type = type,
					}
				end

				if current == "," or current == ";" then
					table.insert(fields, {
						node = field,
						sep = consume_atom() :: cst.Atom<","> | cst.Atom<";">,
					})
				else
					table.insert(fields, {
						node = field,
						sep = nil,
					})

					break
				end
			end

			local close = expect_atom("}") :: cst.Atom<"}">

			return {
				kind = "table",
				braces = { open = open, close = close },
				fields = fields,
			}
		elseif current == "(" or current == "<" then
			-- function type or list type pack
			return error("todo")
		else
			return report(`expected type, but got {display(current, current_span)}`)
		end
	end
end
