--- A span in the source code.
export type Span = vector

--- An identifier, such as `foo` or `bar`.
export type Identifier = {
	span: Span,

	--- The text of the identifier.
	text: string?,
}

--- A number literal, such as `42` or `3.14` or `0xff`.
export type Number = {
	span: Span,

	--- The text of the number.
	text: string?,
}

--- A string literal, such as `"foo"`, `'bar'`, or `[[baz]]`.
export type String = {
	span: Span,

	--- The text of the string.
	text: string?,
}

--- An attribute, such as `@foo`.
export type Attribute = {
	span: Span,

	--- The text of the attribute.
	text: string?,
}

--- Any segment of an interpolated string. This could be the entire string, if
--- it has no exprs, or it could be any part of the string, beginning, middle,
--- or end.
export type IString = {
	span: Span,

	--- The text of the segment.
	text: string?,
}

--- A full AST.
export type Chunk = Block

--- A block of stats, ending with an optional last stat, such as
--- `foo() bar() return baz`.
export type Block = {
	span: Span,

	--- The stats; `foo()` and `bar()`.
	stats: { Stat },

	--- The optional last stat; `return baz`.
	last_stat: LastStat?,
}

--- A statement in a block, such as `foo()` or `local foo = bar`.
export type Stat =
	| Stat_Assign
	| Stat_CompoundAssign
	| Stat_Call
	| Stat_Do
	| Stat_While
	| Stat_Repeat
	| Stat_If
	| Stat_NumericFor
	| Stat_GenericFor
	| Stat_Function
	| Stat_LocalFunction
	| Stat_LocalVariable
	| Stat_Type
	| Stat_TypeFunction

--- An assignment stat, such as `foo, bar = baz, qux` or `foo.bar = baz`.
export type Stat_Assign = {
	kind: "assign",
	span: Span,

	--- The left of the assignment; `foo, bar`.
	left: { Var },

	--- The right of the assignment; `baz, qux`.
	right: { Expr },
}

--- A compound assignment stat, such as `foo += bar` or `foo[bar] -= baz`.
export type Stat_CompoundAssign = {
	kind: "compoundassign",
	span: Span,

	--- The left side of the assignment; `foo`.
	left: Var,

	--- The operator of the assignment; `+=`.
	operator: CompoundOperator,

	--- The right side of the assignment; `bar`.
	right: Expr,
}

--- A compound operator.
export type CompoundOperator = {
	kind: "+=" | "-=" | "*=" | "/=" | "//=" | "%=" | "^=" | "..=",
	span: Span,
}

--- A function call stat, such as `foo.bar:baz()` or `foo()`.
export type Stat_Call = {
	kind: "call",
	span: Span,

	--- A var ending with a call suffix.
	--- 
	--- This var not ending with a call suffix will result in a syntax error
	--- when emitted.
	call: Var,
}

--- A do stat, such as `do foo() end`.
export type Stat_Do = {
	kind: "do",
	span: Span,

	--- The inner block; `foo()`.
	block: Block,
}

--- A while stat, such as `while foo() do bar() end`.
export type Stat_While = {
	kind: "while",
	span: Span,

	--- The condition; `foo()`.
	condition: Expr,

	--- The inner block; `bar()`.
	block: Block,
}

--- A repeat stat, such as `repeat foo() until bar()`.
export type Stat_Repeat = {
	kind: "repeat",
	span: Span,

	--- The inner block; `foo()`.
	block: Block,

	--- The condition; `bar()`.
	condition: Expr,
}

--- An if stat, such as
--- `if foo() then bar() elseif baz() then qux() else quz() end`.
export type Stat_If = {
	kind: "if",
	span: Span,

	--- The branches; `foo then bar() elseif baz then qux()`.
	branches: { IfStatBranch },

	--- The optional else branch; `else quz()`.
	else_block: Block?,
}

--- A branch in an if stat, such as `foo then bar()`.
export type IfStatBranch = {
	span: Span,

	--- The condition; `foo`.
	condition: Expr,

	--- The block; `bar()`.
	block: Block,
}

--- A numeric for loop stat, such as `for foo = 1, 2, 3 do bar() end`.
export type Stat_NumericFor = {
	kind: "numericfor",
	span: Span,

	--- The binding; `foo`.
	binding: Binding,

	--- The start expr; `1`.
	start_expr: Expr,

	--- The end expr; `2`.
	end_expr: Expr,

	--- The optional step expr; `3`.
	step_expr: Expr?,

	--- The block; `bar()`.
	block: Block,
}

--- A generic for loop stat, such as
--- `for foo: bar, baz in qux, quz do quv() end`.
export type Stat_GenericFor = {
	kind: "genericfor",
	span: Span,

	--- The bindings; `foo: bar, baz`.
	bindings: { Binding },

	--- The exprs; `qux, quz`.
	exprs: { Expr },

	--- The block; `quv()`.
	block: Block,
}

--- A function decl stat, such as
--- `@native function foo.bar:baz() return 1 end`.
export type Stat_Function = {
	kind: "function",
	span: Span,

	--- The attributes; `@native`.
	attributes: { Attribute },

	--- The name; `foo.bar`.
	names: { Identifier },

	--- The optional method; `:baz`.
	method: Identifier?,

	--- The function body; `() return 1 end`.
	body: FunctionBody,
}

--- A local function decl stat, such as
--- `@native local function foo() return 1 end`.
export type Stat_LocalFunction = {
	kind: "localfunction",
	span: Span,

	--- The attributes; `@native`.
	attributes: { Attribute },

	--- The name; `foo`.
	name: Identifier,

	--- The function body; `() return 1 end`.
	body: FunctionBody,
}

--- A local variable stat, such as `local foo: bar, baz = qux, quz, quv`.
export type Stat_LocalVariable = {
	kind: "localvariable",
	span: Span,

	--- The bindings; `foo: bar, baz`.
	bindings: { Binding },

	--- The optional exprs; `qux, quz, quv`.
	exprs: { Expr }?,
}

--- A type decl stat, such as `export type foo<bar> = baz`.
export type Stat_Type = {
	kind: "type",
	span: Span,

	--- The optional export; `export`.
	export: boolean,

	--- The name of the type; `foo`.
	name: Identifier,

	--- The optional generic decl; `<bar>`.
	generics: GenericDeclWithDefaults?,

	--- The type; `baz`.
	type: Type,
}

--- A type function decl stat, such as `export type function foo(bar) return
--- types.number end`.
export type Stat_TypeFunction = {
	kind: "typefunction",
	span: Span,

	--- The optional export; `export`.
	export: boolean,

	--- The name of the type function; `foo`.
	name: Identifier,

	--- The function body of the type function; `(bar) return types.number end`.
	body: FunctionBody,
}

--- The last statement in a block, such as `return`, `break`, or `continue`.
export type LastStat = LastStat_Return | LastStat_Break | LastStat_Continue

--- A return last stat, such as `return foo, bar, baz` or `return`.
export type LastStat_Return = {
	kind: "return",
	span: Span,

	--- The optional exprs; `foo, bar, baz`.
	exprs: { Expr },
}

--- A break last stat, such as `break`.
export type LastStat_Break = {
	kind: "break",
	span: Span,
}

--- A continue last stat, such as `continue`.
export type LastStat_Continue = {
	kind: "continue",
	span: Span,
}

--- A variable, such as `foo` or `foo.bar` or `(foo + bar):baz()` or `foo[bar]`.
export type Var = {
	span: Span,

	--- The root of the variable; `foo` and `(foo + bar)`.
	root: VarRoot,

	--- The suffixes of the variable; `.bar` and `:baz()` and `[bar]`.
	suffixes: { VarSuffix },
}

--- The root of a variable, such as `foo` or `(bar + baz)`.
export type VarRoot = VarRoot_Name | VarRoot_Paren

--- A name as a variable, such as `foo`.
export type VarRoot_Name = {
	kind: "name",
	span: Span,

	--- The name.
	name: Identifier,
}

--- A parenthesized expr, such as `(foo)` or `(bar + baz)`.
export type VarRoot_Paren = {
	kind: "paren",
	span: Span,

	--- The expr.
	expr: Expr,
}

--- A suffix of a variable, such as `.foo` or `[bar]` or `:baz(qux)`.
export type VarSuffix = VarSuffix_Name | VarSuffix_Expr | VarSuffix_Call

--- A named index, such as `root.foo`.
export type VarSuffix_Name = {
	kind: "name",
	span: Span,

	--- The name.
	name: Identifier,
}

--- An expr index, such as `root[foo]`.
export type VarSuffix_Expr = {
	kind: "expr",
	span: Span,

	--- The expr.
	expr: Expr,
}

--- A call, such as `root:method(foo)` or `root()`.
export type VarSuffix_Call = {
	kind: "call",
	span: Span,

	--- The optional method; `:method`.
	method: Identifier?,

	--- The arguments; `(foo)`.
	args: { Expr },
}

--- An expression, such as `nil` or `foo + bar` or `if foo then bar else baz`.
export type Expr =
	| Expr_Nil
	| Expr_Boolean
	| Expr_Number
	| Expr_String
	| Expr_Vararg
	| Expr_SimpleIString
	| Expr_ComplexIString
	| Expr_Table
	| Expr_Function
	| Expr_IfElse
	| Expr_Var
	| Expr_Assertion
	| Expr_Unary
	| Expr_Binary

--- The literal expr `nil`.
export type Expr_Nil = {
	kind: "nil",
	span: Span,
}

--- The literal expr `true` or `false`.
export type Expr_Boolean = {
	kind: "boolean",
	span: Span,

	--- The value.
	value: boolean,
}

--- A number literal expr, such as `42` or `3.14` or `0xff`.
export type Expr_Number = {
	kind: "number",
	span: Span,

	--- The number.
	number: Number,
}

--- A string literal expr, such as `"foo"` or `'bar'` or `[[baz]]`.
export type Expr_String = {
	kind: "string",
	span: Span,

	--- The string.
	string: String,
}

--- The literal expr `...`.
export type Expr_Vararg = {
	kind: "vararg",
	span: Span,
}

--- A simple interpolated string expr, such as `'foo bar baz'`.
export type Expr_SimpleIString = {
	kind: "simpleistring",
	span: Span,

	--- The string.
	string: IString,
}

--- A complex interpolated string expr, such as `'foo {bar} baz {qux} quz'`.
export type Expr_ComplexIString = {
	kind: "complexistring",
	span: Span,

	--- The istring segements; `'foo {'` and `} baz {` and `} quz'`.
	segments: { IString },

	--- The exprs; `bar` and `qux`.
	exprs: { Expr },
}

--- A table literal expr, such as `{ foo = bar }` or `{}`.
export type Expr_Table = {
	kind: "table",
	span: Span,

	--- The table literal.
	table: Table,
}

--- An anonymous function expr, such as
--- `@native function(foo, bar) return foo + bar end`.
export type Expr_Function = {
	kind: "function",
	span: Span,

	--- The attributes; `@native`.
	attributes: { Attribute },

	--- The function body; `(foo, bar) return foo + bar end`.
	body: FunctionBody,
}

--- An if-else expr, such as `if foo then bar elseif baz then qux else quz`.
export type Expr_IfElse = {
	kind: "ifelse",
	span: Span,

	--- The branches; `foo the bar elseif baz then qux`.
	branches: { IfElseExprBranch },

	--- The `else` body; `else quz`.
	else_body: Expr,
}

--- A branch of an if-else expr, such as `foo then bar`.
export type IfElseExprBranch = {
	span: Span,

	--- The condition; `foo`.
	condition: Expr,

	--- The body; `bar`.
	body: Expr,
}

--- A var expr, such as `foo.bar[baz]()` or `(foo + bar)`.
export type Expr_Var = {
	kind: "var",
	span: Span,

	--- The var.
	var: Var,
}

--- A type assertion expr, such as `foo :: bar`.
export type Expr_Assertion = {
	kind: "assertion",
	span: Span,

	--- The expr; `foo`.
	expr: Expr,

	--- The type; `bar`.
	type: Type,
}

--- An unary expr, such as `-foo` or `not bar`.
export type Expr_Unary = {
	kind: "unary",
	span: Span,

	--- The operator; `-`.
	operator: UnaryOperator,

	--- The expr; `foo`.
	expr: Expr,
}

--- An unary operator.
export type UnaryOperator = {
	kind: "-" | "not" | "#",
	span: Span,
}

--- A binary expr, such as `foo + bar` or `baz or qux`.
export type Expr_Binary = {
	kind: "binary",
	span: Span,

	--- The left expr; `foo`.
	left: Expr,

	--- The operator; `+`.
	operator: BinaryOperator,

	--- The right expr; `bar`.
	right: Expr,
}

--- A binary operator.
export type BinaryOperator = {
	kind: "+"
		| "-"
		| "*"
		| "/"
		| "//"
		| "%"
		| "^"
		| ".."
		| "<"
		| "<="
		| ">"
		| ">="
		| "=="
		| "~="
		| "and"
		| "or",
	span: Span,
}

--- A function body, such as `<T>(foo: T, ...: bar): baz return 10 end`.
export type FunctionBody = {
	span: Span,

	--- The optional generic decl; `<T>`.
	generics: GenericDecl?,

	--- The parameters; `foo: T`.
	params: { Binding },

	--- The optional varargs; `...: bar`.
	varargs: {
		span: Span,

		--- The optional type; `: bar`.
		type: (Type | GenericTypePack)?,
	}?,

	--- The optional return type; `: baz`.
	ret: ReturnType?,

	--- The block; `return 10`.
	block: Block,
}

--- A binding, such as `foo: bar` or `foo`.
export type Binding = {
	span: Span,

	--- The name of the binding; `foo`.
	name: Identifier,

	--- The optional type; `: bar`.
	type: Type?,
}

--- A table literal, such as `{ foo = bar }`.
export type Table = {
	span: Span,

	--- The fields; `foo = bar`.
	fields: { TableField },
}

--- A table field, such as `foo = bar` or `[baz] = qux` or `quz`.
export type TableField = 
	| TableField_NameKey
	| TableField_ExprKey
	| TableField_NoKey

--- A table field with a name key, such as `foo = bar`.
export type TableField_NameKey = {
	kind: "namekey",
	span: Span,

	--- The name; `foo`.
	name: Identifier,
	
	--- The value; `bar`.
	value: Expr,
}

--- A table field with an expr key, such as `[foo] = bar`.
export type TableField_ExprKey = {
	kind: "exprkey",
	span: Span,

	--- The key; `foo`.
	key: Expr,
	
	--- The value; `bar`.
	value: Expr,
}

--- A table field with no key, such as `foo`.
export type TableField_NoKey = {
	kind: "nokey",
	span: Span,

	--- The value; `foo`.
	value: Expr,
}

--- A generic decl without default types, such as `<A, B, C...>`.
export type GenericDecl = {
	span: Span,

	--- The names in the generic decl; `A, B,`.
	names: { Identifier },

	--- The names of the packs in the generic decl; `C...`.
	packs: { Identifier },
}

--- A generic decl with optional default types, such as
--- `<A, B = number, C... = ...string>`.
export type GenericDeclWithDefaults = {
	span: Span,

	--- The names without defaults; `A`
	names_without_defaults: { Identifier },

	--- The names with defaults; `B = number`
	names_with_defaults: {{
		--- The name; `B`
		name: Identifier,

		--- The default type; `number`
		default: Type,
	}},

	--- The packs without defaults; `foo...`.
	--- 
	--- These can only exist if there are no nodes in `names_with_defaults`.
	packs_without_defaults: { Identifier },

	--- The packs with defaults in the decl; `C... = ...string`.
	packs_with_defaults: {{
		--- The pack name; `C...`
		name: Identifier,

		--- The default type pack; `...string`
		default: TypePack,
	}},
}

--- A return type, such as `foo` or `...bar`.
export type ReturnType = Type | TypePack

--- A type pack, such as `...foo` or `foo...` or `(foo, bar, baz...)`.
export type TypePack = VariadicTypePack | GenericTypePack | ListTypePack

--- A list type pack, such as `(foo, bar, baz...)`.
export type ListTypePack = {
	kind: "list",
	span: Span,

	--- The types; `foo, bar`.
	types: { Type },

	--- The optional tail type; `baz...`.
	tail: TailType?,
}

--- A tail type in a list type pack, such as `...foo` or `bar...`.
export type TailType = VariadicTypePack | GenericTypePack

--- A generic type pack, such as `foo...`.
export type GenericTypePack = {
	kind: "generic",
	span: Span,

	--- The name; `foo`.
	name: Identifier,
}

--- A variadic type pack, such as `...foo`.
export type VariadicTypePack = {
	kind: "variadic",
	span: Span,

	--- The type; `foo`.
	type: Type,
}

--- A type, such as `number` or `(foo, bar) -> baz` or `{ foo }`.
export type Type =
	| Type_Nil
	| Type_Boolean
	| Type_String
	| Type_Name
	| Type_Typeof
	| Type_Array
	| Type_Table
	| Type_Function
	| Type_Paren
	| Type_Optional
	| Type_Union
	| Type_Intersection

--- The literal type `nil`.
export type Type_Nil = {
	kind: "nil",
	span: Span,
}

--- The literal type `true` or `false`.
export type Type_Boolean = {
	kind: "boolean",
	span: Span,

	--- The value.
	value: boolean,
}

--- A string literal type, such as `"foo"` or `'bar'`.
export type Type_String = {
	kind: "string",
	span: Span,

	--- The string.
	string: String,
}

--- A name type, such as `foo` or `foo<bar>` or `foo.bar<baz>`.
export type Type_Name = {
	kind: "name",
	span: Span,

	--- The optional prefix; `foo.`.
	prefix: Identifier?,

	--- The name; `bar`.
	name: Identifier,

	--- The optional generic arguments; `<baz>`.
	generics: { TypeArg }?,
}

--- An argument to a type, such as `foo` or `...bar` or `baz...`.
export type TypeArg = Type | TypePack

--- A typeof type, such as `typeof(foo)`.
export type Type_Typeof = {
	kind: "typeof",
	span: Span,

	--- The expr; `foo`.
	expr: Expr,
}

--- An array type, such as `{ foo }`.
export type Type_Array = {
	kind: "array",
	span: Span,

	--- The type; `foo`.
	type: Type,
}

--- A table type, such as `{ foo: bar, ["baz"]: number, [number]: string }`.
export type Type_Table = {
	kind: "table",
	span: Span,

	--- The fields; `foo: bar` and `["baz"]: number` and `[number]: string`.
	fields: { TableTypeField },
}

--- A table type field, such as `foo: bar` or `["foo"]: bar` or
--- `write [number]: string`.
export type TableTypeField =
	| TableTypeField_Name
	| TableTypeField_String
	| TableTypeField_Indexer

--- A table type field with a name key, such as `read foo: bar` or
--- `baz: number`.
export type TableTypeField_Name = {
	kind: "name",
	span: Span,

	--- The optional access modifier; `read`.
	access: ("read" | "write")?,

	--- The key; `foo`.
	key: Identifier,

	--- The type; `bar`.
	type: Type,
}

--- A table type field with a string key, such as `["foo"]: bar`.
export type TableTypeField_String = {
	kind: "string",
	span: Span,

	--- The optional access modifier; `read`.
	access: ("read" | "write")?,

	--- The key; `"foo"`.
	key: String,

	--- The type; `bar`.
	type: Type,
}

--- A table type indexer field, such as `[number]: string`.
export type TableTypeField_Indexer = {
	kind: "indexer",
	span: Span,

	--- The optional access modifier; `read`.
	access: ("read" | "write")?,

	--- The index type; `number`.
	index: Type,

	--- The value type; `string`.
	value: Type,
}

--- A function type, such as `<T>(foo: T, ...bar) -> baz`.
export type Type_Function = {
	kind: "function",
	span: Span,

	--- The optional generic decl; `<T>`.
	generics: GenericDecl?,

	--- The parameters; `foo: T`.
	params: {{
		--- The optional name; `foo`.
		name: Identifier?,

		--- The type; `T`.
		type: Type,
	}},

	--- The optional tail parameter; `...bar`.
	tail: TailType?,

	--- The return type; `baz`.
	ret: ReturnType,
}

--- A parenthesized type, such as `(foo)`.
export type Type_Paren = {
	kind: "paren",
	span: Span,

	--- The type; `foo`.
	type: Type,
}

--- An optional type, such as `foo?`.
export type Type_Optional = {
	kind: "optional",
	span: Span,

	--- The type; `foo`.
	type: Type,
}

--- A union type, such as `| foo | bar` or `foo | bar`.
export type Type_Union = {
	kind: "union",
	span: Span,

	--- The types; `foo` and `bar`.
	types: { Type },
}

--- An intersection type, such as `& foo & bar` or `foo & bar`.
export type Type_Intersection = {
	kind: "intersection",
	span: Span,

	--- The types; `foo` and `bar`.
	types: { Type },
}

return {}