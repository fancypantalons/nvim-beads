describe("util", function()
    local util = require("nvim-beads.util")

    describe("split_lines_with_newlines", function()
        it("should handle empty array", function()
            local result = util.split_lines_with_newlines({})
            assert.are.same({}, result)
        end)

        it("should handle array with no newlines", function()
            local input = { "line 1", "line 2", "line 3" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same(input, result)
        end)

        it("should split single line with one newline", function()
            local input = { "line 1\nline 2" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "line 1", "line 2" }, result)
        end)

        it("should split single line with multiple newlines", function()
            local input = { "line 1\nline 2\nline 3" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "line 1", "line 2", "line 3" }, result)
        end)

        it("should handle leading newline", function()
            local input = { "\nline 1" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "", "line 1" }, result)
        end)

        it("should handle trailing newline", function()
            local input = { "line 1\n" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "line 1", "" }, result)
        end)

        it("should handle multiple consecutive newlines", function()
            local input = { "line 1\n\nline 2" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "line 1", "", "line 2" }, result)
        end)

        it("should handle mixed array with some lines containing newlines", function()
            local input = { "line 1", "line 2\nline 3", "line 4" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "line 1", "line 2", "line 3", "line 4" }, result)
        end)

        it("should handle empty string", function()
            local input = { "" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "" }, result)
        end)

        it("should handle line with only newline", function()
            local input = { "\n" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "", "" }, result)
        end)

        it("should preserve empty lines from newlines", function()
            local input = { "first\n\n\nlast" }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({ "first", "", "", "last" }, result)
        end)

        it("should handle complex multi-line markdown content", function()
            local input = {
                "# Description",
                "",
                "This is a description\nwith embedded newlines\n\nand blank lines",
            }
            local result = util.split_lines_with_newlines(input)
            assert.are.same({
                "# Description",
                "",
                "This is a description",
                "with embedded newlines",
                "",
                "and blank lines",
            }, result)
        end)
    end)
end)
