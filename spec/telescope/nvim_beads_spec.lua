describe("telescope nvim_beads extension", function()
    local extension

    before_each(function()
        -- Mock telescope if not available
        package.loaded["telescope"] = {
            register_extension = function(ext)
                extension = ext
                return ext
            end,
        }
    end)

    it("should register with telescope", function()
        local ok, result = pcall(require, "telescope._extensions.nvim_beads")
        assert.is_true(ok, "Extension should load without errors")
        assert.is_not_nil(result, "Extension should return a value")
    end)

    it("should export list and ready functions", function()
        local ext = require("telescope._extensions.nvim_beads")
        assert.is_not_nil(extension, "Extension should be registered")
        assert.is_not_nil(extension.exports, "Extension should have exports")
        assert.is_not_nil(extension.exports.list, "Extension should export list function")
        assert.is_not_nil(extension.exports.ready, "Extension should export ready function")
        assert.is_not_nil(extension.exports.nvim_beads, "Extension should export nvim_beads function")
    end)

    it("should have list as the default action", function()
        local ext = require("telescope._extensions.nvim_beads")
        assert.are.equal(extension.exports.nvim_beads, extension.exports.list, "nvim_beads should be the same as list")
    end)
end)
