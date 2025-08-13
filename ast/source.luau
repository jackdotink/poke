local top: number = 0
local cyc: { number } = {}

local buf: { buffer } = {}
local lfs: { { number } } = {}

local function create(text: string | buffer): number
	local id: number
	if #cyc ~= 0 then
		id = table.remove(cyc) :: number
	else
		top += 1
		id = top
	end

	buf[id] = if type(text) == "string" then buffer.fromstring(text) else text
	lfs[id] = {}

	return id
end

local function delete(id: number)
	buf[id] = nil
	lfs[id] = nil
	table.insert(cyc, id)
end

local function text(id: number): buffer
	return assert(buf[id], "attempted to get text of deleted source")
end

local function fill(id: number): { number }
	return lfs[id]
end

local function line(id: number, byte: number): number
	local lfs = lfs[id]
	local lo, hi = 1, #lfs

	if byte > lfs[hi] then
		return hi + 1
	end

	while lo < hi do
		local m = (lo + hi) // 2

		if lfs[m] < byte then
			lo = (m + 1)
		elseif lfs[m] > byte then
			hi = (m - 1)
		else
			return m
		end
	end

	return lo
end

return {
	create = create,
	delete = delete,
	text = text,
	fill = fill,
	line = line,
}
