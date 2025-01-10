local sources = require("./sources")
local ast = require("./ast")

local function unreachable(_: never): never
	error("unreachable")
end

local output = {}

local function write(str: string)
	table.insert(output, str)
end

local display_block: (node: ast.Block) -> ()
local display_stat: (node: ast.Stat) -> ()
local display_last_stat: (node: ast.LastStat) -> ()
local display_var: (node: ast.Var) -> ()
local display_var_root: (node: ast.VarRoot) -> ()
local display_var_suffix: (node: ast.VarSuffix) -> ()
local display_function_arg: (node: ast.FunctionArg) -> ()
local display_expr: (node: ast.Expr) -> ()
local display_function_body: (node: ast.FunctionBody) -> ()
local display_binding: (node: ast.Binding) -> ()
local display_table: (node: ast.Table) -> ()
local display_generic_decl: (node: ast.GenericDecl) -> ()
local display_generic_decl_with_defaults: (node: ast.GenericDeclWithDefaults) -> ()
local display_return_type: (node: ast.ReturnType) -> ()
local display_type_pack: (node: ast.TypePack) -> ()
local display_tail_type: (node: ast.TailType) -> ()
local display_type: (node: ast.Type) -> ()

local function display_identifier(node: ast.Identifier)
	if node.text then
		write(node.text :: string)
	else
		write(sources.read_span(node.span))
	end
end

local function display_number(node: ast.Number)
	if node.text then
		write(node.text :: string)
	else
		write(sources.read_span(node.span))
	end
end

local function display_string(node: ast.String)
	if node.text then
		write(node.text :: string)
	else
		write(sources.read_span(node.span))
	end
end

local function display_attribute(node: ast.Attribute)
	if node.text then
		write(node.text :: string)
	else
		write(sources.read_span(node.span))
	end
end

local function display_istring(node: ast.IString)
	if node.text then
		write(node.text :: string)
	else
		write(sources.read_span(node.span))
	end
end

function display_block(node: ast.Block)
	for _, stat in node.stats do
		display_stat(stat)
		write("\n")
	end

	local last_stat = node.last_stat
	if last_stat then
		display_last_stat(last_stat)
		write("\n")
	end
end

function display_stat(node: ast.Stat)
	if node.kind == "assign" then
		for i, var in node.left do
			if i ~= 1 then
				write(", ")
			end

			display_var(var)
		end

		write(" = ")

		for i, expr in node.right do
			if i ~= 1 then
				write(", ")
			end

			display_expr(expr)
		end
	elseif node.kind == "compoundassign" then
		node = node :: ast.Stat_CompoundAssign
		display_var(node.left)
		write(" " .. node.operator.kind .. " ")
		display_expr(node.right)
	elseif node.kind == "call" then
		node = node :: ast.Stat_Call
		display_var(node.call)
	elseif node.kind == "do" then
		node = node :: ast.Stat_Do
		write("do\n")
		display_block(node.block)
		write("end")
	elseif node.kind == "while" then
		node = node :: ast.Stat_While
		write("while ")
		display_expr(node.condition)
		write(" do\n")
		display_block(node.block)
		write("end")
	elseif node.kind == "repeat" then
		node = node :: ast.Stat_Repeat
		write("repeat\n")
		display_block(node.block)
		write("until ")
		display_expr(node.condition)
	elseif node.kind == "if" then
		node = node :: ast.Stat_If
		write("if ")

		for i, branch in node.branches do
			if i ~= 1 then
				write("elseif ")
			end

			display_expr(branch.condition)
			write(" then\n")
			display_block(branch.block)
		end

		local else_block = node.else_block
		if else_block then
			write("else\n")
			display_block(else_block)
		end

		write("end")
	elseif node.kind == "numericfor" then
		node = node :: ast.Stat_NumericFor
		write("for ")
		display_binding(node.binding)
		write(" = ")
		display_expr(node.start_expr)
		write(", ")
		display_expr(node.end_expr)

		local step_expr = node.step_expr
		if step_expr then
			write(", ")
			display_expr(step_expr)
		end

		write(" do\n")
		display_block(node.block)
		write("end")
	elseif node.kind == "genericfor" then
		node = node :: ast.Stat_GenericFor
		write("for ")

		for i, binding in node.bindings do
			if i ~= 1 then
				write(", ")
			end

			display_binding(binding)
		end

		write(" in ")

		for i, expr in node.exprs do
			if i ~= 1 then
				write(", ")
			end

			display_expr(expr)
		end

		write(" do\n")
		display_block(node.block)
		write("end")
	elseif node.kind == "function" then
		node = node :: ast.Stat_Function

		for _, attribute in node.attributes do
			display_attribute(attribute)
			write("\n")
		end

		write("function ")
		
		for i, name in node.names do
			if i ~= 1 then
				write(".")
			end

			display_identifier(name)
		end

		local method = node.method
		if method then
			write(":")
			display_identifier(method)
		end

		display_function_body(node.body)
	elseif node.kind == "localfunction" then
		node = node :: ast.Stat_LocalFunction

		for _, attribute in node.attributes do
			display_attribute(attribute)
			write("\n")
		end

		write("local function ")
		display_identifier(node.name)
		display_function_body(node.body)
	elseif node.kind == "localvariable" then
		node = node :: ast.Stat_LocalVariable

		for i, binding in node.bindings do
			if i ~= 1 then
				write(", ")
			end

			display_binding(binding)
		end

		local exprs = node.exprs
		if exprs then
			write(" = ")

			for i, expr in exprs do
				if i ~= 1 then
					write(", ")
				end

				display_expr(expr)
			end
		end
	elseif node.kind == "type" then
		node = node :: ast.Stat_Type

		if node.export then
			write("export ")
		end

		write("type ")
		display_identifier(node.name)

		local generics = node.generics
		if generics then
			display_generic_decl_with_defaults(generics)
		end

		write(" = ")

		display_type(node.type)
	else
		unreachable(node.kind :: never)
	end
end

function display_last_stat(node: ast.LastStat)
	if node.kind == "return" then
		write("return")

		for i, expr in node.exprs do
			if i ~= 1 then
				write(",")
			end

			write(" ")
			display_expr(expr)
		end
	elseif node.kind == "break" then
		write("break")
	elseif node.kind == "continue" then
		write("continue")
	else
		unreachable(node.kind)
	end
end

function display_var(node: ast.Var)
	display_var_root(node.root)

	for _, suffix in node.suffixes do
		display_var_suffix(suffix)
	end
end

function display_var_root(node: ast.VarRoot)
	if node.kind == "name" then
		display_identifier(node.name)
	elseif node.kind == "paren" then
		write("(")
		display_expr(node.expr)
		write(")")
	else
		unreachable(node.kind)
	end
end

function display_var_suffix(node: ast.VarSuffix)
	if node.kind == "name" then
		write(".")
		display_identifier(node.name)
	elseif node.kind == "expr" then
		write("[")
		display_expr(node.expr)
		write("]")
	elseif node.kind == "call" then
		local method = node.method
		if method then
			write(":")
			display_identifier(method)
		end

		display_function_arg(node.arg)
	else
		unreachable(node.kind)
	end
end

function display_function_arg(node: ast.FunctionArg)
	if node.kind == "pack" then
		write("(")

		for i, expr in node.exprs do
			if i ~= 1 then
				write(", ")
			end

			display_expr(expr)
		end

		write(")")
	elseif node.kind == "table" then
		write(" ")
		display_table(node.table)
	elseif node.kind == "string" then
		write(" ")
		display_string(node.string)
	else
		unreachable(node.kind)
	end
end

function display_expr(node: ast.Expr)
	if node.kind == "nil" then
		write("nil")
	elseif node.kind == "boolean" then
		write(if node.value then "true" else "false")
	elseif node.kind == "number" then
		display_number(node.number)
	elseif node.kind == "string" then
		display_string(node.string)
	elseif node.kind == "vararg" then
		write("...")
	elseif node.kind == "simpleistring" then
		display_istring(node.string)
	elseif node.kind == "complexistring" then
		local segments = node.segments
		local exprs = node.exprs

		for i = 1, #segments do
			local segment = segments[i]
			local expr = exprs[i]

			display_istring(segment)

			if expr then
				display_expr(expr)
			else
				break
			end
		end
	elseif node.kind == "table" then
		display_table(node.table)
	elseif node.kind == "function" then
		node = node :: ast.Expr_Function

		for _, attribute in node.attributes do
			display_attribute(attribute)
			write("\n")
		end

		display_function_body(node.body)
	elseif node.kind == "ifelse" then
		write("if ")

		for i, branch in node.branches do
			if i ~= 1 then
				write(" elseif ")
			end

			display_expr(branch.condition)
			write(" then ")
			display_expr(branch.body)
		end

		write(" else ")
		display_expr(node.else_body)
	elseif node.kind == "var" then
		node = node :: ast.Expr_Var

		display_var(node.var)
	elseif node.kind == "assertion" then
		display_expr(node.expr)
		write(" :: ")
		display_type(node.type)
	elseif node.kind == "unary" then
		node = node :: ast.Expr_Unary

		write(node.operator.kind .. " ")
		display_expr(node.expr)
	elseif node.kind == "binary" then
		display_expr(node.left)
		write(" " .. node.operator.kind .. " ")
		display_expr(node.right)
	else
		unreachable(node.kind)
	end
end

function display_function_body(node: ast.FunctionBody)
	local generics = node.generics
	if generics then
		display_generic_decl(generics)
	end

	write("(")

	for i, binding in node.params do
		if i ~= 1 then
			write(", ")
		end

		display_binding(binding)
	end

	local varargs = node.varargs
	if varargs then
		if #node.params ~= 0 then
			write(", ")
		end

		write("...")

		local type = varargs.type
		if type then
			write(": ")

			if type.kind == "generic" then
				display_identifier(type.name)
				write("...")
			else
				display_type(type)
			end
		end
	end

	write(")")

	local ret = node.ret
	if ret then
		write(": ")
		display_return_type(ret)
	end

	write("\n")
	display_block(node.block)
	write("end")
end

function display_binding(node: ast.Binding)
	display_identifier(node.name)

	local type = node.type
	if type then
		write(": ")
		display_type(type)
	end
end

function display_table(node: ast.Table)
	write("{\n")

	for _, field in node.fields do
		if field.kind == "namekey" then
			display_identifier(field.name)
			write(" = ")
			display_expr(field.value)
		elseif field.kind == "exprkey" then
			write("[")
			display_expr(field.key)
			write("] = ")
			display_expr(field.value)
		elseif field.kind == "nokey" then
			display_expr(field.value)
		else
			unreachable(field.kind)
		end

		write(",\n")
	end

	write("}")
end

function display_generic_decl(node: ast.GenericDecl)
	write("<")

	local written = false

	for i, name in node.names do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(name)
	end

	for i, pack in node.packs do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(pack)
		write("...")
	end

	write(">")
end

function display_generic_decl_with_defaults(node: ast.GenericDeclWithDefaults)
	write("<")

	local written = false

	for i, name in node.names_without_defaults do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(name)
	end

	for i, name in node.names_with_defaults do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(name.name)
		write(" = ")
		display_type(name.default)
	end

	for i, pack in node.packs_without_defaults do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(pack)
		write("...")
	end

	for i, pack in node.packs_with_defaults do
		if written then
			write(", ")
		else
			written = true
		end

		display_identifier(pack.name)
		write(" = ")
		display_type_pack(pack.default)
	end
end

function display_return_type(node: ast.ReturnType)
	if 
		node.kind == "variadic"
		or node.kind == "generic"
		or node.kind == "list"
	then
		display_type_pack(node)
	else
		display_type(node)
	end
end

function display_type_pack(node: ast.TypePack)
	if node.kind == "list" then
		write("(")

		local written = false

		for i, type in node.types do
			if written then
				write(", ")
			else
				written = true
			end

			display_type(type)
		end

		local tail = node.tail
		if tail then
			if written then
				write(", ")
			end

			display_tail_type(tail)
		end
	else
		display_tail_type(node)
	end
end

function display_tail_type(node: ast.TailType)
	if node.kind == "generic" then
		display_identifier(node.name)
		write("...")
	elseif node.kind == "variadic" then
		display_type(node.type)
	else
		unreachable(node.kind)
	end
end

function display_type(node: ast.Type)
	if node.kind == "nil" then
		write("nil")
	elseif node.kind == "boolean" then
		write(if node.value then "true" else "false")
	elseif node.kind == "string" then
		display_string(node.string)
	elseif node.kind == "name" then
		local prefix = node.prefix
		if prefix then
			display_identifier(prefix)
		end

		display_identifier(node.name)
		
		local generics = node.generics
		if generics then
			write("<")

			for i, generic in generics do
				if i ~= 1 then
					write(", ")
				end

				if
					generic.kind == "list"
					or generic.kind == "generic"
					or generic.kind == "variadic"
				then
					display_type_pack(generic)
				else
					display_type(generic)
				end
			end

			write(">")
		end
	elseif node.kind == "typeof" then
		write("typeof(")
		display_expr(node.expr)
		write(")")
	elseif node.kind == "array" then
		write("{ ")
		display_type(node.type)
		write(" }")
	elseif node.kind == "table" then
		write("{\n")

		for _, field in node.fields do
			local access = field.access
			if access then
				write(access .. " ")
			end

			if field.kind == "name_prop" then
				display_identifier(field.name)
				write(": ")
				display_type(field.type)
			elseif field.kind == "string_prop" then
				write("[")
				display_string(field.key)
				write("]: ")
				display_type(field.type)
			elseif field.kind == "indexer" then
				write("[")
				display_type(field.key)
				write("]: ")
				display_type(field.value)
			else
				unreachable(field.kind)
			end

			write(",\n")
		end

		write("}")
	elseif node.kind == "function" then
		node = (node :: any) :: ast.Type_Function

		local generics = node.generics
		if generics then
			display_generic_decl(generics)
		end

		write("(")

		for i, param in node.params do
			if i ~= 1 then
				write(", ")
			end

			local name = param.name
			if name then
				display_identifier(name)
				write(": ")
			end

			display_type(param.type)
		end

		local tail = node.tail
		if tail then
			if #node.params ~= 0 then
				write(", ")
			end

			display_tail_type(tail)
		end

		write(") -> ")
		display_return_type(node.ret)
	elseif node.kind == "paren" then
		node = node :: ast.Type_Paren

		write("(")
		display_type(node.type)
		write(")")
	elseif node.kind == "optional" then
		display_type(node.type)
		write("?")
	elseif node.kind == "union" then
		node = node :: ast.Type_Union

		local types = node.types

		if #types == 1 then
			write("| ")
			display_type(types[1])
		else
			for i, type in types do
				if i ~= 1 then
					write(" | ")
				end

				display_type(type)
			end
		end
	elseif node.kind == "intersection" then
		local types = node.types

		if #types == 1 then
			write("& ")
			display_type(types[1])
		else
			for i, type in types do
				if i ~= 1 then
					write(" & ")
				end

				display_type(type)
			end
		end
	else
		unreachable(node.kind)
	end
end

return {
	identifier = display_identifier,
	number = display_number,
	string = display_string,
	attribute = display_attribute,
	istring = display_istring,

	block = display_block,
	stat = display_stat,
	last_stat = display_last_stat,
	var = display_var,
	var_root = display_var_root,
	var_suffix = display_var_suffix,
	function_arg = display_function_arg,
	expr = display_expr,
	function_body = display_function_body,
	binding = display_binding,
	table = display_table,
	generic_decl = display_generic_decl,
	generic_decl_with_defaults = display_generic_decl_with_defaults,
	return_type = display_return_type,
	type_pack = display_type_pack,
	tail_type = display_tail_type,
	type = display_type,
}
