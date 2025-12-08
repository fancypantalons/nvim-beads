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
        local telescope_routing_test_cases = {
            { name = "list", bd_args = { "list" } },
            { name = "search", bd_args = { "search", "foo" } },
            { name = "blocked", bd_args = { "blocked" } },
            { name = "ready", bd_args = { "ready" } },
        }

        for _, test_case in ipairs(telescope_routing_test_cases) do
            it("routes '" .. test_case.name .. "' command to show_issues", function()
                local called_with_bd_args
                local called_with_opts
                core.show_issues = function(bd_args, opts)
                    called_with_bd_args = bd_args
                    called_with_opts = opts
                end

                core.execute_with_ui(test_case.bd_args)

                assert.same(test_case.bd_args, called_with_bd_args)
                if test_case.name == "list" then
                    assert.same({}, called_with_opts)
                end
            end)
        end

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
        local terminal_routing_test_cases = {
            { name = "show", bd_args = { "show", "bd-123" }, expected_args = { "bd-123" } },
            { name = "create", bd_args = { "create", "--title", "Test" }, expected_args = { "--title", "Test" } },
            {
                name = "update",
                bd_args = { "update", "bd-1", "--status", "closed" },
                expected_args = { "bd-1", "--status", "closed" },
            },
            { name = "unknown", bd_args = { "unknown", "arg1", "arg2" }, expected_args = { "arg1", "arg2" } },
        }

        for _, test_case in ipairs(terminal_routing_test_cases) do
            it("routes '" .. test_case.name .. "' command to terminal buffer", function()
                local called_command
                local called_args
                mock_util.execute_command_in_scratch_buffer = function(command, args)
                    called_command = command
                    called_args = args
                end

                core.execute_with_ui(test_case.bd_args)

                assert.equals(test_case.name, called_command)
                assert.same(test_case.expected_args, called_args)
            end)
        end

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
