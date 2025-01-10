--- A span in the source code.
export type Span = vector

--- A list of nodes separated by separators, such as `foo, bar, baz`.
export type Separated<Node, Sep> = { Pair<Node, Sep> }

--- A pair of a node and optional separator.
export type Pair<Node, Sep> = { node: Node, sep: Sep? }

--- Delimiters that surround something, such as `(foo)` or `{bar}`.
export type Delimited<Open, Close> = {
	--- The opening delimiter.
	open: Open,

	--- The closing delimiter.
	close: Close,
}

--- Trivia unimportant to parsing; comments and whitespace.
export type Trivia = {
	kind: "comment" | "whitespace",

	--- The span of the trivia in the source code.
	span: Span,

	--- The text of the trivia.
	text: string?,
}

--- An Atom; a symbol, keyword, eof, and in some uncommon cases, an identifier
--- that cannot change, like `continue`.
export type Atom<Kind> = {
	kind: Kind,

	--- The span of the symbol.
	span: Span,

	--- The trivia that precedes the symbol.
	trivia: { Trivia },
}

--- An identifier, such as `foo` or `bar`.
export type Identifier = {
	--- The span of the identifier.
	span: Span,

	--- The trivia that precedes the identifier.
	trivia: { Trivia },

	--- The text of the identifier.
	text: string?,
}

--- A number literal, such as `42` or `3.14` or `0xff`.
export type Number = {
	--- The span of the number.
	span: Span,

	--- The trivia that precedes the number.
	trivia: { Trivia },

	--- The text of the number.
	text: string?,
}

--- A string literal, such as `"foo"`, `'bar'`, or `[[baz]]`.
export type String = {
	--- The span of the string.
	span: Span,

	--- The trivia that precedes the string.
	trivia: { Trivia },

	--- The text of the string.
	text: string?,
}

--- An attribute, such as `@foo`.
export type Attribute = {
	--- The span of the attribute.
	span: Span,

	--- The trivia that precedes the attribute.
	trivia: { Trivia },

	--- The text of the attribute.
	text: string?,
}

--- Any segment of an interpolated string. This could be the entire string, if
--- it has no exprs, or it could be any part of the string, beginning, middle,
--- or end.
export type IString = {
	--- The span of the segment.
	span: Span,

	--- The trivia that precedes the segment.
	trivia: { Trivia },

	--- The text of the segment.
	text: string?,
}

--- A full CST with a block and eof.
export type Cst = {
	--- The block of stats.
	block: Block,

	--- The eof token.
	eof: Atom<"eof">,
}

--- A block of stats, ending with an optional last stat, such as 
--- `foo(); bar() return baz;`.
export type Block = {
	--- The stats; `foo();` and `bar()`.
	stats: Separated<Stat, Atom<";">>,

	--- The optional last stat; `return baz;`.
	last_stat: {
		--- The last stat; `return baz`.
		stat: LastStat,

		--- The optional semicolon; `;`.
		semicolon: Atom<";">?,
	}
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

--- An assignment stat, such as `foo, bar = baz, qux` or `foo = bar`.
export type Stat_Assign = {
	kind: "assign",

	--- The left of the assignment; `foo, bar`.
	left: Separated<Var, Atom<",">>,

	--- The equals sign; `=`.
	equals: Atom<"=">,

	--- The right of the assignment; `baz, qux`.
	right: Separated<Expr, Atom<",">>,
}

--- A compound assignment stat, such as `foo += bar`.
export type Stat_CompoundAssign = {
	kind: "compoundassign",

	--- The left side of the assignment; `foo`.
	left: Var,

	--- The compound operator; `+=` .
	operator: CompoundOperator,

	--- The right side of the assignment; `bar`.
	right: Expr,
}

--- A compound operator.
export type CompoundOperator = 
	| Atom<"+=">
	| Atom<"-=">
	| Atom<"*=">
	| Atom<"/=">
	| Atom<"//=">
	| Atom<"%=">
	| Atom<"^=">
	| Atom<"..=">

--- A function call stat, such as `foo.bar()` or `baz()`.
export type Stat_Call = {
	kind: "call",

	--- A var ending with a call suffix.
	--- 
	--- This var not ending with a call suffix will result in a syntax error
	--- when emitted.
	call: Var,
}

--- A do stat, such as `do foo() end`.
export type Stat_Do = {
	kind: "do",
	
	--- The `do` token.
	do_tok: Atom<"do">,

	--- The inner block; `foo()`.
	block: Block,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A while stat, such as `while foo do bar() end`.
export type Stat_While = {
	kind: "while",

	--- The `while` token.
	while_tok: Atom<"while">,

	--- The condition; `foo`.
	condition: Expr,

	--- The `do` token.
	do_tok: Atom<"do">,

	--- The block; `bar()`.
	block: Block,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A repeat stat, such as `repeat foo() until bar`.
export type Stat_Repeat = {
	kind: "repeat",

	--- The `repeat` token.
	repeat_tok: Atom<"repeat">,
	
	--- The block; `foo()`.
	block: Block,

	--- The `until` token.
	until_tok: Atom<"until">,

	--- The condition; `bar`.
	condition: Expr,
}

--- An if stat, such as
--- `if foo then bar() elseif baz then qux() else quz() end`.
export type Stat_If = {
	kind: "if",

	--- The `if` token.
	if_tok: Atom<"if">,

	--- The branches; `foo then bar() elseif baz then qux()`.
	branches: Separated<IfStatBranch, Atom<"elseif">>,

	--- The optional else branch; `else quz()`.
	else_branch: {
		--- The `else` token.
		else_tok: Atom<"else">,

		--- The else branch block; `quz()`.
		block: Block,
	}?,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A branch in an if stat, such as `foo then bar()`
export type IfStatBranch = {
	--- The condition; `foo`.
	condition: Expr,

	--- The `then` token.
	then_tok: Atom<"then">,

	--- The block; `bar()`.
	block: Block,
}

--- A numeric for loop stat, such as `for foo = 1, 2, 3 do bar() end`.
export type Stat_NumericFor = {
	kind: "numericfor",

	--- The `for` token.
	for_tok: Atom<"for">,

	--- The binding; `foo`.
	binding: Binding,

	--- The equals token; `=`.
	equals: Atom<"=">,

	--- The start expr; `1`.
	start_expr: Expr,

	--- The comma between the start and end; `,`.
	comma: Atom<",">,

	--- The end expr; `2`.
	end_expr: Expr,

	--- The optional step; `, 3`.
	step: {
		--- The comma between the end and step; `,`.
		comma: Atom<",">,

		--- The step expr; `3`.
		expr: Expr,
	}?,

	--- The `do` token.
	do_tok: Atom<"do">,

	--- The block; `bar()`.
	block: Block,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A generic for loop stat, such as
--- `for foo: bar, baz in qux, quz do quv() end`.
export type Stat_GenericFor = {
	kind: "genericfor",

	--- The `for` token.
	for_tok: Atom<"for">,

	--- The bindings; `foo: bar, baz`.
	bindings: Separated<Binding, Atom<",">>,

	--- The `in` token.
	in_tok: Atom<"in">,

	--- The exprs; `qux, quz`.
	exprs: Separated<Expr, Atom<",">>,

	--- The `do` token.
	do_tok: Atom<"do">,

	--- The block; `quv()`.
	block: Block,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A function decl stat, such as
--- `@native function foo.bar:baz() return 1 end`.
export type Stat_Function = {
	kind: "function",
	
	--- The attributes; `@native`.
	attributes: { Attribute },

	--- The `function` token.
	function_tok: Atom<"function">,

	--- The name; `foo.bar`.
	names: Separated<Identifier, Atom<".">>,

	--- The optional method; `:baz`.
	method: {
		--- The colon; `:`.
		colon: Atom<":">,
		
		--- The method name; `baz`.
		name: Identifier,
	}?,

	--- The function body; `() return 1 end`.
	body: FunctionBody,
}

--- A local function decl stat, such as
--- `@native local function foo() return 1 end`.
export type Stat_LocalFunction = {
	kind: "localfunction",
	
	--- The attributes; `@native`.
	attributes: { Attribute },

	--- The `local` token.
	local_tok: Atom<"local">,

	--- The `function` token.
	function_tok: Atom<"function">,

	--- The name; `foo`.
	name: Identifier,

	--- The function body; `() return 1 end`.
	body: FunctionBody,
}

--- A local variable stat, such as `local foo: bar, baz = qux, quz, quv`.
export type Stat_LocalVariable = {
	kind: "localvariable",

	--- The `local` token.
	local_tok: Atom<"local">,

	--- The bindings; `foo: bar, baz`.
	bindings: Separated<Binding, Atom<",">>,

	--- The optional values; `= qux, quz, quv`.
	values: {
		--- The equals; `=`.
		equals: Atom<"=">,

		--- The exprs; `qux, quz, quv`.
		exprs: Separated<Expr, Atom<",">>,
	}?,
}

--- A type decl stat, such as `export type foo<bar> = baz`.
export type Stat_Type = {
	kind: "type",

	--- The optional `export` token.
	export_tok: Atom<"export">?,

	--- The `type` token.
	type_tok: Atom<"type">,

	--- The name of the type; `foo`.
	name: Identifier,

	--- The optional generic decl; `<bar>`.
	generics: GenericDeclWithDefaults?,

	--- The equals token; `=`.
	equals: Atom<"=">,

	--- The type; `baz`.
	type: Type,
}

--- The last statement in a block, such as `return`, `break`, or `continue`.
export type LastStat = LastStat_Return | LastStat_Break | LastStat_Continue

--- A return last stat, such as `return foo, bar, baz` or `return`.
export type LastStat_Return = {
	kind: "return",

	--- The `return` token.
	return_tok: Atom<"return">,

	--- The returned exprs; `foo, bar, baz`.
	exprs: Separated<Expr, Atom<",">>,
}

--- A `break` last stat.
export type LastStat_Break = {
	kind: "break",
	
	--- The `break` token.
	tok: Atom<"break">,
}

--- A `continue` last stat.
export type LastStat_Continue = {
	kind: "continue",

	--- The `continue` token.
	tok: Atom<"continue">,
}

--- A variable, such as `foo` or `foo.bar` or `(foo + bar):baz()` or `foo[bar]`.
export type Var = {
	--- The root of the variable; `foo`.
	root: VarRoot,

	--- The suffixes of the variable; `.bar` and `:baz()` and `[bar]`.
	suffixes: { VarSuffix },
}

--- The root of a variable, such as `foo` or `(bar + baz)`.
export type VarRoot = VarRoot_Name | VarRoot_Paren

--- A name as a variable, such as `foo`.
export type VarRoot_Name = {
	kind: "name",

	--- The name token.
	name: Identifier,
}

--- A parenthesized expr, such as `(foo)` or `(bar + baz)`.
export type VarRoot_Paren = {
	kind: "paren",

	--- The parens surrounding the expr; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The expr; `foo`.
	expr: Expr,
}

--- A suffix of a variable, such as `.foo` or `[bar]` or `:baz(qux)`.
export type VarSuffix = VarSuffix_Name | VarSuffix_Expr | VarSuffix_Call

--- A named index, such as `root.foo`.
export type VarSuffix_Name = {
	kind: "name",

	--- The dot; `.`.
	dot: Atom<"">,

	--- The name; `foo`.
	name: Identifier,
}

--- An expr index, such as `root[foo]`.
export type VarSuffix_Expr = {
	kind: "expr",

	--- The brackets surrounding the expr; `[` and `]`.
	bracks: Delimited<Atom<"[">, Atom<"]">>,

	--- The expr; `foo`.
	expr: Expr,
}

--- A call, such as `root:method(foo)` or `root()`.
export type VarSuffix_Call = {
	kind: "call",

	--- The optional method; `:method`.
	method: {
		--- The colon; `:`.
		colon: Atom<":">,

		--- The name; `method`.
		name: Identifier,
	}?,

	--- The argument; `(foo)`.
	arg: FunctionArg,
}

--- An argument to a call, such as `(foo, bar)` or `()` or `"baz"`.
export type FunctionArg = FunctionArg_Pack | FunctionArg_Table | FunctionArg_String

--- Pack argument to a call, such as `(foo, bar)` or `()`.
export type FunctionArg_Pack = {
	kind: "pack",

	--- The parens surrounding the pack; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The exprs; `foo, bar`.
	exprs: Separated<Expr, Atom<",">>,
}

--- Table argument to a call, such as `{ foo = bar }` or `{}`.
export type FunctionArg_Table = {
	kind: "table",

	--- The table literal.
	table: Table,
}

--- String argument to a call, such as `"foo"` or `'bar'`.
export type FunctionArg_String = {
	kind: "string",

	--- The string token.
	token: String,
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

	--- The `nil` token.
	token: Atom<"nil">,
}

--- The literal expr `true` or `false`.
export type Expr_Boolean = {
	kind: "boolean",

	--- The `true` or `false` token.
	token: Atom<"true"> | Atom<"false">,
}

--- A number literal expr, such as `42` or `3.14` or `0xff`.
export type Expr_Number = {
	kind: "number",

	--- The number token.
	token: Number,
}

--- A string literal expr, such as `"foo"` or `'bar'` or `[[baz]]`.
export type Expr_String = {
	kind: "string",

	--- The string token.
	token: String,
}

--- The literal expr `...`.
export type Expr_Vararg = {
	kind: "vararg",

	--- The `...` token.
	token: Atom<"...">,
}

--- A simple interpolated string expr, such as `'foo bar baz'`.
export type Expr_SimpleIString = {
	kind: "simple_istring",

	--- The string.
	string: IString,
}

--- A complex interpolated string expr, such as `'foo {bar} baz {qux} quz'`.
export type Expr_ComplexIString = {
	kind: "complex_istring",

	--- The first segment; `'foo {`.
	first: IString,

	--- The remaining exprs and istring segments; `bar} baz {qux} quz'`.
	rest: Separated<Expr, IString>,
}

--- A table literal expr, such as `{ foo = bar }`.
export type Expr_Table = {
	kind: "table",

	--- The table literal.
	table: Table,
}

--- An anonymous function expr, such as
--- `@native function(foo, bar) return foo + bar end`.
export type Expr_Function = {
	kind: "function",
	
	--- The function attributes; `@native`.
	attributes: { Attribute },

	--- The `function` token; `function`.
	function_tok: Atom<"function">,
	
	--- The function body; `(foo, bar) return foo + bar end`.
	body: FunctionBody,
}

--- An if-else expr, such as `if foo then bar elseif baz then qux else quz`.
export type Expr_IfElse = {
	kind: "ifelse",

	--- The `if` token; `if`.
	if_tok: Atom<"if">,

	--- The branches separated by `elseif`; `foo then bar elseif baz then qux`.
	branches: Separated<IfElseExprBranch, Atom<"elseif">>,

	--- The `else` token; `else`.
	else_tok: Atom<"else">,

	--- The `else` body; `quz`.
	else_body: Expr,
}

--- A branch of an if-else expr, such as `foo then bar`.
export type IfElseExprBranch = {
	--- The condition; `foo`.
	condition: Expr,

	--- The `then` token; `then`.
	then_tok: Atom<"then">,
	
	--- The body; `bar`.
	body: Expr,
}

--- A var expr, such as `foo.bar[baz]()` or `(foo + bar)`.
export type Expr_Var = {
	kind: "var",

	--- The var.
	var: Var,
}

--- A type assertion expr, such as `foo :: bar`.
export type Expr_Assertion = {
	kind: "assertion",

	--- The expr; `foo`.
	expr: Expr,

	--- The colons; `::`
	colons: Atom<"::">,

	--- The type; `bar`.
	type: Type,
}

--- An unary expr, such as `-foo` or `not bar`.
export type Expr_Unary = {
	kind: "unary",

	--- The operator; `-`
	operator: UnaryOperator,

	--- The expr; `foo`
	expr: Expr,
}

--- An unary operator.
export type UnaryOperator = 
	| Atom<"-">
	| Atom<"not">
	| Atom<"#">

--- A binary expr, such as `foo + bar` or `baz or qux`.
export type Expr_Binary = {
	kind: "binary",

	--- The left expr; `foo`.
	left: Expr,

	--- The operator; `+`
	operator: BinaryOperator,

	--- The right expr; `bar`.
	right: Expr,
}

--- A binary operator.
export type BinaryOperator = 
	| Atom<"+">
	| Atom<"-">
	| Atom<"*">
	| Atom<"/">
	| Atom<"//">
	| Atom<"%">
	| Atom<"^">
	| Atom<"..">
	| Atom<"<">
	| Atom<"<=">
	| Atom<">">
	| Atom<">=">
	| Atom<"==">
	| Atom<"~=">
	| Atom<"and">
	| Atom<"or">

--- A function body, such as `<T>(foo: T, ...: bar): baz return 10 end`.
export type FunctionBody = {
	--- The optional generic decl; `<T>`.
	generics: GenericDecl?,

	--- The parentheses surrounding the parameters; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The parameters; `foo: T,`.
	params: Separated<Binding, Atom<",">>,

	--- The optional varargs; `...: bar`.
	varargs: {
		--- The dots; `...`.
		dots: Atom<"...">,

		--- The optional type; `: bar`.
		type: {
			--- The colon; `:`.
			colon: Atom<":">,

			--- The type; `bar`.
			type: Type | GenericTypePack,
		}?,
	}?,

	--- The optional return type; `: baz`.
	ret: {
		--- The colon; `:`.
		colon: Atom<":">,

		--- The type; `baz`.
		type: ReturnType,
	}?,

	--- The block; `return 10`.
	block: Block,

	--- The `end` token.
	end_tok: Atom<"end">,
}

--- A binding, such as `foo: bar` or `foo`.
export type Binding = {
	--- The name of the binding; `foo`.
	name: Identifier,

	--- The optional type; `: bar`.
	type: {
		--- The colon; `:`.
		colon: Atom<":">,

		--- The type; `bar`.
		type: Type,
	}?,
}

--- A table literal, such as `{ foo = bar }`.
export type Table = {
	--- The braces surrounding the fields; `{` and `}`.
	braces: Delimited<Atom<"{">, Atom<"}">>,

	--- The fields; `foo = bar`.
	fields: Separated<TableField, Atom<","> | Atom<";">>,
}

--- A table field, such as `foo = bar` or `[baz] = qux` or `quz`.
export type TableField = 
	| TableField_NameKey
	| TableField_ExprKey
	| TableField_NoKey

--- A table field with a name key, such as `foo = bar`.
export type TableField_NameKey = {
	kind: "namekey",

	--- The name; `foo`.
	name: Identifier,

	--- The equals; `=`.
	equals: Atom<"=">,

	--- The value; `bar`.
	value: Expr,
}

--- A table field with an expr key, such as `[foo] = bar`.
export type TableField_ExprKey = {
	kind: "exprkey",

	--- The brackets surrounding the key; `[` and `]`.
	bracks: Delimited<Atom<"[">, Atom<"]">>,

	--- The key; `foo`.
	key: Expr,

	--- The equals; `=`.
	equals: Atom<"=">,

	--- The value; `bar`.
	value: Expr,
}

--- A table field with no key, such as `foo`.
export type TableField_NoKey = {
	kind: "nokey",

	--- The value; `foo`.
	value: Expr,
}

--- A generic decl without default types; `<A, B, C...>`.
export type GenericDecl = {
	--- The angles surrounding the generic decl; `<` and `>`.
	angles: Delimited<Atom<"<">, Atom<">">>,

	--- The names in the generic decl; `A, B,`.
	names: Separated<Identifier, Atom<",">>,

	--- The packs in the generic decl; `C...`.
	packs: Separated<{
		--- The name; `C`.
		name: Identifier,
	
		--- The trailing dots; `...`.
		dots: Atom<"...">,
	}, Atom<",">>,
}

--- A generic decl with optional default types;
--- `<A, B = number, C... = ...string>`.
export type GenericDeclWithDefaults = {
	--- The angles surrounding the generic decl; `<` and `>`.
	angles: Delimited<Atom<"<">, Atom<">">>,

	--- The names without defaults in the decl; `A,`.
	names_without_defaults: Separated<Identifier, Atom<",">>,

	--- The names with defaults in the decl; `B = number,`.
	names_with_defaults: Separated<{
		--- The name; `B`.
		name: Identifier,
	
		--- The equals sign; `=`.
		equals: Atom<"=">,
	
		--- The default type; `number`.
		default: Type,
	}, Atom<",">>,

	--- The packs without defaults in the decl; `foo...`.
	--- 
	--- These can only exist if there are no nodes in `names_with_defaults`.
	packs_without_defaults: Separated<{
		--- The name; `foo`.
		name: Identifier,
	
		--- The trailing dots; `...`.
		dots: Atom<"...">,
	}, Atom<",">>,

	--- The packs with defaults in the decl; `C... = ...string`.
	packs_with_defaults: Separated<{
		--- The name; `C`.
		name: Identifier,
	
		--- The trailing dots; `...`.
		dots: Atom<"...">,
	
		--- The equals sign; `=`.
		equals: Atom<"=">,
	
		--- The default type pack; `...string`.
		default: TypePack,
	}, Atom<",">>,
}

--- A return type, such as `foo` or `...bar`.
export type ReturnType = Type | TailType

--- A type pack, such as `...foo` or `foo...` or `(foo, bar, baz...)`.
export type TypePack = VariadicTypePack | GenericTypePack | ListTypePack

--- A list type pack, such as `(foo, bar, baz...)`.
export type ListTypePack = {
	kind: "list",

	--- The parentheses surrounding the types; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The types; `foo, bar,`.
	types: Separated<Type, Atom<",">>,

	--- The optional tail type; `baz...`.
	tail: TailType?,
}

--- A tail type in a list type pack, such as `...foo` or `bar...`.
export type TailType = VariadicTypePack | GenericTypePack

--- A generic type pack, such as `foo...`.
export type GenericTypePack = {
	kind: "generic",

	--- The name; `foo`.
	name: Identifier,

	--- The dots; `...`.
	dots: Atom<"...">,
}

--- A variadic type pack, such as `...foo`.
export type VariadicTypePack = {
	kind: "variadic",

	--- The dots; `...`.
	dots: Atom<"...">,

	--- The type; `foo`.
	type: Type,
}

--- A type, such as `number` or `(foo, bar) -> baz` or `{ foo }`.
export type Type =
	| Type_Nil
	| Type_Boolean
	| Type_String
	| Type_Reference
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

	--- The `nil` token.
	token: Atom<"nil">,
}

--- The literal type `true` or `false`.
export type Type_Boolean = {
	kind: "boolean",

	--- The `true` or `false` token.
	token: Atom<"true"> | Atom<"false">,
}

--- A string literal type, such as `"foo"` or `'bar'`.
export type Type_String = {
	kind: "string",

	--- The string token.
	token: String,
}

--- A reference type, such as `foo` or `foo<bar>` or `foo.bar<baz>`.
export type Type_Reference = {
	kind: "reference",

	--- The optional prefix; `foo.`.
	prefix: {
		--- The name; `foo`
		name: Identifier,

		--- The dot; `.`
		dot: Atom<".">,
	}?,

	--- The name; `bar`.
	name: Identifier,

	--- The optional generics; `<baz>`.
	generics: {
		--- The angles; `<` and `>`.
		angles: Delimited<Atom<"<">, Atom<">">>,

		--- The generic types; `baz`.
		types: Separated<TypeArg, Atom<",">>,
	}?,
}

--- An argument to a type, such as `foo` or `...bar` or `baz...`.
export type TypeArg = Type | TypePack

--- A typeof type, such as `typeof(foo)`.
export type Type_Typeof = {
	kind: "typeof",

	--- The typeof token.
	typeof_tok: Atom<"typeof">,

	--- The parentheses surrounding the expr; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The expr; `foo`.
	expr: Expr,
}

--- An array type, such as `{ foo }`.
export type Type_Array = {
	kind: "array",

	--- The braces surrounding the type; `{` and `}`.
	braces: Delimited<Atom<"{">, Atom<"}">>,

	--- The type; `foo`.
	type: Type,
}

--- A table type, such as `{ foo: bar, ["baz"]: number, [number]: string }`.
export type Type_Table = {
	kind: "table",

	--- The braces surrounding the fields; `{` and `}`.
	braces: Delimited<Atom<"{">, Atom<"}">>,

	--- The fields; `foo: bar` and `["baz"]: number` and `[number]: string`.
	fields: Separated<TableTypeField, Atom<","> | Atom<";">>,
}

--- A table type field, such as `foo: bar` or `["foo"]: bar` or
--- `write [number]: string`.
export type TableTypeField =
	| TableTypeField_NameProp
	| TableTypeField_StringProp
	| TableTypeField_Indexer

--- A table type field with a name key, such as `read foo: bar` or
--- `baz: number`.
export type TableTypeField_NameProp = {
	kind: "nameprop",

	--- The optional access modifier; `read`.
	access: (Atom<"read"> | Atom<"write">)?,

	--- The name; `foo`.
	name: Identifier,

	--- The colon; `:`.
	colon: Atom<":">,

	--- The type; `bar`.
	type: Type,
}

--- A table type field with a string key, such as `["foo"]: bar`.
export type TableTypeField_StringProp = {
	kind: "stringprop",

	--- The optional access modifier; `read`.
	access: (Atom<"read"> | Atom<"write">)?,

	--- The brackets surrounding the key; `[` and `]`.
	bracks: Delimited<Atom<"[">, Atom<"]">>,

	--- The key; `"foo"`.
	key: String,

	--- The colon; `:`.
	colon: Atom<":">,

	--- The type; `bar`.
	type: Type,
}

--- A table type indexer field, such as `[number]: string`.
export type TableTypeField_Indexer = {
	kind: "indexer",

	--- The optional access modifier; `read`.
	access: (Atom<"read"> | Atom<"write">)?,

	--- The brackets surrounding the key; `[` and `]`.
	bracks: Delimited<Atom<"[">, Atom<"]">>,

	--- The key; `number`.
	key: Type,

	--- The colon; `:`.
	colon: Atom<":">,

	--- The type; `bar`.
	type: Type,
}

--- A function type, such as `<T>(foo: T, ...bar) -> baz`.
export type Type_Function = {
	kind: "function",

	--- The optional generic decl; `<T>`.
	generics: GenericDecl?,

	--- The parentheses surrounding the parameters; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The parameters; `foo: T,`.
	params: Separated<{
		--- The optional name of the parameter; `foo:`.
		name: {
			--- The name; `foo`.
			name: Identifier,

			--- The colon; `:`.
			colon: Atom<":">,
		}?,

		--- The type of the parameter; `T`
		type: Type,
	}, Atom<",">>,

	--- The optional tail parameter; `...bar`.
	tail: TailType?,

	--- The arrow; `->`
	arrow: Atom<"->">,

	--- The return type; `baz`.
	ret: ReturnType,
}

--- A parenthesized type, such as `(foo)`.
export type Type_Paren = {
	kind: "paren",

	--- The parentheses surrounding the type; `(` and `)`.
	parens: Delimited<Atom<"(">, Atom<")">>,

	--- The type; `foo`.
	type: Type,
}

--- An optional type, such as `foo?`.
export type Type_Optional = {
	kind: "optional",

	--- The type; `foo`.
	type: Type,

	--- The question mark; `?`.
	question: Atom<"?">,
}

--- A union type, such as `| foo | bar` or `foo | bar`.
export type Type_Union = {
	kind: "union",

	--- The optional leading pipe; `|`.
	leading: Atom<"|">,

	--- The types; `foo | bar`.
	types: Separated<Type, Atom<"|">>,
}

--- An intersection type, such as `& foo & bar` or `foo & bar`.
export type Type_Intersection = {
	kind: "union",

	--- The optional leading ampersand; `&`.
	leading: Atom<"&">,

	--- The types; `foo & bar`.
	types: Separated<Type, Atom<"&">>,
}

return {}
