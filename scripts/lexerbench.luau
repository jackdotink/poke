--!nocheck
local args = { ... }

local lexer = require("../ast/" .. args[1])
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

local next = lexer.next
local ESC = string.char(27)

local total_time_acc, byte_acc = 0, 0

for _, file in files do
	local input = require("../" .. file).str

	local sid = source.create(input)
	local bytes = #input * 100

	local this_time_acc = 0

	for i = 1, 100 do
		table.clear(source.fill(sid))
		lexer.load(sid)

		local start = os.clock()
		repeat
			local kind, _ = next()
		until kind == "eof"
		this_time_acc += os.clock() - start
	end

	total_time_acc += this_time_acc
	byte_acc += bytes

	if not silent then
		print(`\z
			{ESC}[1;32mCase: {ESC}[0m{file}; \z
			{ESC}[1;32mTime: {ESC}[0m{string.format("%d", this_time_acc * 1000)}ms; \z
			{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", bytes / 1_000_000 / this_time_acc)} MB/s\z
		`)
	end
end

print(`\z
	{ESC}[1;32mTime: {ESC}[0m{string.format("%d", total_time_acc * 1000)}ms; \z
	{ESC}[1;32mRate: {ESC}[0m{string.format("%.2f", byte_acc / 1_000_000 / total_time_acc)} MB/s\z
`)
