--- Unit tests for nvim-beads core.show_issues function
--- Tests Telescope integration for displaying issues

local assertions = require("test_utilities.assertions")

describe("nvim-beads.core.show_issues", function()
    local core
    local original_telescope

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.core"] = nil
        core = require("nvim-beads.core")

        -- Save original telescope
        original_telescope = package.loaded["telescope"]
    end)

    after_each(function()
        -- Restore original telescope
        package.loaded["telescope"] = original_telescope
    end)

    it("should load telescope extension and call show_issues", function()
        local show_issues_called = false
        local show_issues_bd_args = nil
        local show_issues_opts = nil

        package.loaded["telescope"] = {
            extensions = {
                nvim_beads = {
                    show_issues = function(bd_args, opts)
                        show_issues_called = true
                        show_issues_bd_args = bd_args
                        show_issues_opts = opts
                    end,
                },
            },
            load_extension = function() end,
        }

        core.show_issues({ "list", "--status", "open" }, { type = "bug" })

        assert.is_true(show_issues_called)
        assert.same({ "list", "--status", "open" }, show_issues_bd_args)
        assert.same({ type = "bug" }, show_issues_opts)
    end)

    it("should load telescope extension if not already loaded", function()
        local load_extension_called = false
        local extension_name = nil

        package.loaded["telescope"] = {
            extensions = {},
            load_extension = function(name)
                load_extension_called = true
                extension_name = name
                -- Simulate extension being loaded
                package.loaded["telescope"].extensions.nvim_beads = {
                    show_issues = function() end,
                }
            end,
        }

        core.show_issues({ "ready" }, {})

        assert.is_true(load_extension_called)
        assert.equals("nvim_beads", extension_name)
    end)

    it("should show error when telescope is not installed", function()
        local original_pcall = _G.pcall

        -- Mock pcall to make require("telescope") fail
        _G.pcall = function(fn, ...)
            if fn == require and select(1, ...) == "telescope" then
                return false, "module 'telescope' not found"
            end
            return original_pcall(fn, ...)
        end

        assertions.assert_error_notification(function()
            core.show_issues({ "list" }, {})
        end, "Telescope not found")

        _G.pcall = original_pcall
    end)

    it("should handle nil opts", function()
        local show_issues_opts = "NOT_SET"

        package.loaded["telescope"] = {
            extensions = {
                nvim_beads = {
                    show_issues = function(_, opts)
                        show_issues_opts = opts
                    end,
                },
            },
            load_extension = function() end,
        }

        core.show_issues({ "list" }, nil)

        assert.same({}, show_issues_opts)
    end)
end)
