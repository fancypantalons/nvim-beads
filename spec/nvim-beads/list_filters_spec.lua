--- spec/nvim-beads/list_filters_spec.lua

local core = require("nvim-beads.core")

describe("core.parse_list_filters", function()
	it("should parse a state and a pluralized type", function()
		local fargs = { "open", "bugs" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "open", type = "bug" }, filters)
	end)

	it("should parse a single state argument", function()
		local fargs = { "ready" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "ready", type = nil }, filters)
	end)

	it("should parse a single pluralized type argument", function()
		local fargs = { "features" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = nil, type = "feature" }, filters)
	end)

	it("should parse a single singular type argument", function()
		local fargs = { "task" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = nil, type = "task" }, filters)
	end)

	it("should handle 'all' as a state", function()
		local fargs = { "all", "tasks" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "all", type = "task" }, filters)
	end)

	it("should handle 'all' as a type", function()
		local fargs = { "in_progress", "all" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "in_progress", type = "all" }, filters)
	end)

	it("should handle 'all' for both state and type", function()
		local fargs = { "all", "all" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "all", type = "all" }, filters)
	end)

	it("should return nils for empty arguments table", function()
		local fargs = {}
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = nil, type = nil }, filters)
	end)

	it("should handle a single state argument that could also be a type", function()
		-- 'task' is a valid type, but if it's the only argument, it's ambiguous
		-- The logic assumes [state] [type], so the first arg is always checked as a state first.
		-- This is a known ambiguity. Let's test the inverse case from the 'task' test above.
		local fargs = { "open" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "open", type = nil }, filters)
	end)

	it("should ignore unknown arguments in the first position", function()
		local fargs = { "foobar" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = nil, type = nil }, filters)
	end)

	it("should ignore unknown arguments but parse known ones", function()
		local fargs = { "foobar", "bug" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = nil, type = "bug" }, filters)
	end)

	it("should parse a known state and ignore an unknown type", function()
		local fargs = { "closed", "foobar" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "closed", type = nil }, filters)
	end)

	it("should handle too many arguments by ignoring extras", function()
		local fargs = { "closed", "feature", "extra_arg" }
		local filters = core.parse_list_filters(fargs)
		assert.same({ state = "closed", type = "feature" }, filters)
	end)

	it("should handle nil fargs gracefully", function()
		local filters = core.parse_list_filters(nil)
		assert.same({ state = nil, type = nil }, filters)
	end)
end)
