--!nocheck
local args = { ... }

local parser = (require)("../ast/" .. args[1])
local source = require("../ast/source")

local silent = args[2] == "silent"

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

local ESC = string.char(27)

local total_time_acc, byte_acc = 0, 0

for _, case in files do
	local input = (require)("../" .. case).str

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
			if type(result.result) == "string" then
				print(`{ESC}[0;31mError: {result.result}`)
			else
				print(`{ESC}[0;31mError: {result.result.msg}`)
			end
		end
	end

	total_time_acc += this_time_acc
	byte_acc += bytes

	if not silent then
		print(`\z
			{ESC}[1;32mCase: {ESC}[0m{case}; \z
			{ESC}[1;32mTime: {ESC}[0m{string.format("%d", this_time_acc * 1000)}ms; \z
			{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", bytes / 1_000_000 / this_time_acc)} MB/s\z
		`)
	end
end

print(`\z
	{ESC}[1;32mTime: {ESC}[0m{string.format("%d", total_time_acc * 1000)}ms; \z
	{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", byte_acc / 1_000_000 / total_time_acc)} MB/s\z
`)
