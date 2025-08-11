local parse = (require)("./ast/" .. (...))

local cases = {
	"luau.web",
	"ast",
	"parse",
	"jecs",
}

local ESC = string.char(27)

local time_acc, byte_acc = 0, 0

for _, case in cases do
	local input = buffer.fromstring((require)("@self/" .. case).str)
	local bytes = buffer.len(input) * 100

	local result: { success: boolean, result: any }
	local start = os.clock()

	for i = 1, 100 do
		result = parse.safe(input, parse.parse_chunk) :: any
	end

	local time = os.clock() - start

	time_acc += time
	byte_acc += bytes

	if not result.success then
		print(`{ESC}[0;31mError: {result.result.msg} @ {result.result.span.x}:{result.result.span.y}`)
	end

	print(`\z
		{ESC}[1;32mCase: {ESC}[0m{case}; \z
		{ESC}[1;32mTime: {ESC}[0m{string.format("%d", time * 1000)}ms; \z
		{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", bytes / 1_000_000 / time)} MB/s\z
	`)
end

print(`\z
	{ESC}[1;32mTime: {ESC}[0m{string.format("%d", time_acc * 1000)}ms; \z
	{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", byte_acc / 1_000_000 / time_acc)} MB/s\z
`)
