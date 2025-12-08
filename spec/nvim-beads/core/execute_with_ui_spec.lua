--- Integration tests for execute_with_ui infrastructure

local env = require("test_utilities.env")
local assertions = require("test_utilities.assertions")

describe("execute_with_ui", function()
    local core
    local mock_beads
    local mock_util

    before_each(function()
        env.setup_mock_env()

        -- Mock util module
        mock_util = {
            execute_command_in_scratch_buffer = function() end,
        }
        package.loaded["nvim-beads.util"] = mock_util

        -- Mock telescope for show_issues
        mock_beads = {
            show_issues = function() end,
        }

        -- Load core module
        package.loaded["nvim-beads.core"] = nil
        core = require("nvim-beads.core")

        -- Replace show_issues with mock
        core.show_issues = mock_beads.show_issues
    end)

    after_each(function()
        env.teardown_mock_env()
    end)

    describe("telescope routing", function()
        it("routes 'list' command to show_issues", function()
            local called_with_bd_args
            local called_with_opts
            core.show_issues = function(bd_args, opts)
                called_with_bd_args = bd_args
                called_with_opts = opts
            end

            core.execute_with_ui({ "list" })

            assert.same({ "list" }, called_with_bd_args)
            assert.same({}, called_with_opts)
        end)

        it("routes 'search' command to show_issues", function()
            local called_with_bd_args
            core.show_issues = function(bd_args)
                called_with_bd_args = bd_args
            end

            core.execute_with_ui({ "search", "foo" })

            assert.same({ "search", "foo" }, called_with_bd_args)
        end)

        it("routes 'blocked' command to show_issues", function()
            local called_with_bd_args
            core.show_issues = function(bd_args)
                called_with_bd_args = bd_args
            end

            core.execute_with_ui({ "blocked" })

            assert.same({ "blocked" }, called_with_bd_args)
        end)

        it("routes 'ready' command to show_issues", function()
            local called_with_bd_args
            core.show_issues = function(bd_args)
                called_with_bd_args = bd_args
            end

            core.execute_with_ui({ "ready" })

            assert.same({ "ready" }, called_with_bd_args)
        end)

        it("passes filter table to show_issues", function()
            local called_with_opts
            core.show_issues = function(_, opts)
                called_with_opts = opts
            end

            local filter = { status = "open", type = "bug" }
            core.execute_with_ui({ "list" }, filter)

            assert.same(filter, called_with_opts)
        end)

        it("passes bd_args with multiple arguments to show_issues", function()
            local called_with_bd_args
            core.show_issues = function(bd_args)
                called_with_bd_args = bd_args
            end

            core.execute_with_ui({ "search", "authentication", "bug" })

            assert.same({ "search", "authentication", "bug" }, called_with_bd_args)
        end)
    end)

    describe("terminal routing", function()
        it("routes 'show' command to terminal buffer", function()
            local called_command
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(command, args)
                called_command = command
                called_args = args
            end

            core.execute_with_ui({ "show", "bd-123" })

            assert.equals("show", called_command)
            assert.same({ "bd-123" }, called_args)
        end)

        it("routes 'create' command to terminal buffer", function()
            local called_command
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(command, args)
                called_command = command
                called_args = args
            end

            core.execute_with_ui({ "create", "--title", "Test" })

            assert.equals("create", called_command)
            assert.same({ "--title", "Test" }, called_args)
        end)

        it("routes 'update' command to terminal buffer", function()
            local called_command
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(command, args)
                called_command = command
                called_args = args
            end

            core.execute_with_ui({ "update", "bd-1", "--status", "closed" })

            assert.equals("update", called_command)
            assert.same({ "bd-1", "--status", "closed" }, called_args)
        end)

        it("routes unknown command to terminal buffer", function()
            local called_command
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(command, args)
                called_command = command
                called_args = args
            end

            core.execute_with_ui({ "unknown", "arg1", "arg2" })

            assert.equals("unknown", called_command)
            assert.same({ "arg1", "arg2" }, called_args)
        end)

        it("handles command with no additional args", function()
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(_, args)
                called_args = args
            end

            core.execute_with_ui({ "compact" })

            assert.same({}, called_args)
        end)
    end)

    describe("command name and args splitting", function()
        it("splits first arg as command name for terminal routing", function()
            local called_command
            mock_util.execute_command_in_scratch_buffer = function(command)
                called_command = command
            end

            core.execute_with_ui({ "show", "bd-1" })

            assert.equals("show", called_command)
        end)

        it("passes remaining args after command name to terminal", function()
            local called_args
            mock_util.execute_command_in_scratch_buffer = function(_, args)
                called_args = args
            end

            core.execute_with_ui({ "delete", "bd-1", "--force" })

            assert.same({ "bd-1", "--force" }, called_args)
        end)

        it("preserves all args for telescope routing", function()
            local called_with_bd_args
            core.show_issues = function(bd_args)
                called_with_bd_args = bd_args
            end

            core.execute_with_ui({ "list", "--status", "open" })

            assert.same({ "list", "--status", "open" }, called_with_bd_args)
        end)
    end)

    describe("argument validation and error handling", function()
        it("shows error when args is empty", function()
            assertions.assert_error_notification(function()
                core.execute_with_ui({})
            end, "non%-empty table")
        end)

        it("shows error when args is not a table", function()
            assertions.assert_error_notification(function()
                core.execute_with_ui("not a table")
            end, ".")
        end)

        it("handles nil opts gracefully", function()
            local called_with_opts
            core.show_issues = function(_, opts)
                called_with_opts = opts
            end

            core.execute_with_ui({ "list" }, nil)

            assert.same({}, called_with_opts)
        end)
    end)
end)
