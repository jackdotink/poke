local parser = (require)("./ast/" .. (...))
local source = require("./ast/source")

local cases = {
	"jecs",
	"ast",
	"parse",
	"luaup",
}

local ESC = string.char(27)

local total_time_acc, byte_acc = 0, 0

for _, case in cases do
	local input = (require)("@self/" .. case).str

	local sid = source.create(input)
	local bytes = #input * 100

	local this_time_acc = 0

	for i = 1, 100 do
		local result: any
		table.clear(source.fill(sid))

		local start = os.clock()
		result = parser.safe(sid, parser.parse_chunk)
		this_time_acc += os.clock() - start

		if not result.success then
			print(`{ESC}[0;31mError: {result.result.msg} @ {result.result.line or -1}:{result.result.span.x}:{result.result.span.y}`)
		end
	end

	total_time_acc += this_time_acc
	byte_acc += bytes

	print(`\z
		{ESC}[1;32mCase: {ESC}[0m{case}; \z
		{ESC}[1;32mTime: {ESC}[0m{string.format("%d", this_time_acc * 1000)}ms; \z
		{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", bytes / 1_000_000 / this_time_acc)} MB/s\z
	`)
end

print(`\z
	{ESC}[1;32mTime: {ESC}[0m{string.format("%d", total_time_acc * 1000)}ms; \z
	{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", byte_acc / 1_000_000 / total_time_acc)} MB/s\z
`)
