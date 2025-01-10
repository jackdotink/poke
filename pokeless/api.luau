local ast = require("./ast")
local display = require("./display")

local api = {}

do
	api.identifier = {}
	api.identifier.display = display.identifier

	function api.identifier.from_raw(name: string): ast.Identifier
		return {
			kind = "identifier",
			span = vector.zero,

			name = name,
		}
	end

	api.identifier.new = api.identifier.from_raw
end

do
	api.string = {}

	function api.string.from_raw(string: string): ast.String
		return {
			kind = "string",
			span = vector.zero,

			string = string,
		}
	end

	api.string.new = api.string.from_raw
end

return api
