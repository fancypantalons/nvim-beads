--- Unit tests for nvim-beads.issue.diff generate_update_commands function
--- Tests command generation from diff changes to bd CLI commands

local env = require("test_utilities.env")

describe("nvim-beads.issue.diff", function()
    local diff

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.diff"] = nil
        diff = require("nvim-beads.issue.diff")
    end)

    describe("generate_update_commands", function()
        describe("metadata field updates", function()
            local metadata_test_cases = {
                {
                    name = "title change",
                    changes = {
                        metadata = { title = "New Title" },
                    },
                    expected_command = { "bd", "update", "bd-1", "--title", "New Title" },
                },
                {
                    name = "priority change",
                    changes = {
                        metadata = { priority = 1 },
                    },
                    expected_command = { "bd", "update", "bd-1", "--priority", "1" },
                },
                {
                    name = "assignee change",
                    changes = {
                        metadata = { assignee = "jane.smith" },
                    },
                    expected_command = { "bd", "update", "bd-1", "--assignee", "jane.smith" },
                },
                {
                    name = "assignee removal",
                    changes = {
                        metadata = { assignee = "" },
                    },
                    expected_command = { "bd", "update", "bd-1", "--assignee", "" },
                },
            }

            for _, test_case in ipairs(metadata_test_cases) do
                it("should generate command for " .. test_case.name, function()
                    local commands = diff.generate_update_commands("bd-1", test_case.changes, nil)

                    assert.equals(1, #commands)
                    assert.same(test_case.expected_command, commands[1])
                end)
            end

            it("should combine multiple metadata changes into single command", function()
                local changes = {
                    metadata = {
                        title = "Updated Title",
                        priority = 0,
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                local cmd = commands[1]
                -- Check that the command has all expected elements
                assert.equals("bd", cmd[1])
                assert.equals("update", cmd[2])
                assert.equals("bd-1", cmd[3])
                -- Find positions of --title and --priority flags
                local has_title = false
                local has_priority = false
                for i = 4, #cmd, 2 do
                    if cmd[i] == "--title" and cmd[i + 1] == "Updated Title" then
                        has_title = true
                    elseif cmd[i] == "--priority" and cmd[i + 1] == "0" then
                        has_priority = true
                    end
                end
                assert.is_true(has_title)
                assert.is_true(has_priority)
            end)
        end)

        describe("text section updates", function()
            local section_test_cases = {
                {
                    name = "description change",
                    changes = { sections = { description = "New description text" } },
                    expected_command = { "bd", "update", "bd-1", "--description", "New description text" },
                },
                {
                    name = "acceptance_criteria change",
                    changes = { sections = { acceptance_criteria = "Must pass all tests" } },
                    expected_command = { "bd", "update", "bd-1", "--acceptance", "Must pass all tests" },
                },
                {
                    name = "design change",
                    changes = { sections = { design = "Use MVVM pattern" } },
                    expected_command = { "bd", "update", "bd-1", "--design", "Use MVVM pattern" },
                },
                {
                    name = "notes change",
                    changes = { sections = { notes = "Additional implementation notes" } },
                    expected_command = { "bd", "update", "bd-1", "--notes", "Additional implementation notes" },
                },
                {
                    name = "empty string for text sections",
                    changes = { sections = { description = "" } },
                    expected_command = { "bd", "update", "bd-1", "--description", "" },
                },
            }

            for _, test_case in ipairs(section_test_cases) do
                it("should generate command for " .. test_case.name, function()
                    local commands = diff.generate_update_commands("bd-1", test_case.changes, nil)

                    assert.equals(1, #commands)
                    assert.same(test_case.expected_command, commands[1])
                end)
            end

            it("should combine multiple section changes into single command", function()
                local changes = {
                    sections = {
                        description = "New desc",
                        design = "New design",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                local cmd = commands[1]
                -- Check command structure
                assert.equals("bd", cmd[1])
                assert.equals("update", cmd[2])
                assert.equals("bd-1", cmd[3])
                -- Find --description and --design flags
                local has_description = false
                local has_design = false
                for i = 4, #cmd, 2 do
                    if cmd[i] == "--description" and cmd[i + 1] == "New desc" then
                        has_description = true
                    elseif cmd[i] == "--design" and cmd[i + 1] == "New design" then
                        has_design = true
                    end
                end
                assert.is_true(has_description)
                assert.is_true(has_design)
            end)
        end)

        describe("status transitions", function()
            it("should generate update command for in_progress status", function()
                local changes = {
                    status = "in_progress",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "update", "bd-1", "--status", "in_progress" }, commands[1])
            end)

            it("should generate update command for blocked status", function()
                local changes = {
                    status = "blocked",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "update", "bd-1", "--status", "blocked" }, commands[1])
            end)

            it("should generate close command for closed status", function()
                local changes = {
                    status = "closed",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "close", "bd-1" }, commands[1])
            end)

            it("should generate reopen command for open status", function()
                local changes = {
                    status = "open",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "reopen", "bd-1" }, commands[1])
            end)
        end)

        describe("label operations", function()
            it("should generate commands for label additions", function()
                local changes = {
                    labels = {
                        add = { "ui", "backend" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                assert.same({ "bd", "label", "add", "bd-1", "ui" }, commands[1])
                assert.same({ "bd", "label", "add", "bd-1", "backend" }, commands[2])
            end)

            it("should generate commands for label removals", function()
                local changes = {
                    labels = {
                        remove = { "old-label", "deprecated" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                assert.same({ "bd", "label", "remove", "bd-1", "old-label" }, commands[1])
                assert.same({ "bd", "label", "remove", "bd-1", "deprecated" }, commands[2])
            end)

            it("should generate commands for both label additions and removals", function()
                local changes = {
                    labels = {
                        add = { "new-label" },
                        remove = { "old-label" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                -- Removals should come before additions
                assert.same({ "bd", "label", "remove", "bd-1", "old-label" }, commands[1])
                assert.same({ "bd", "label", "add", "bd-1", "new-label" }, commands[2])
            end)
        end)

        describe("dependency operations", function()
            it("should generate commands for dependency additions", function()
                local changes = {
                    dependencies = {
                        add = { "bd-120", "bd-121" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                assert.same({ "bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks" }, commands[1])
                assert.same({ "bd", "dep", "add", "bd-1", "bd-121", "--type", "blocks" }, commands[2])
            end)

            it("should generate commands for dependency removals", function()
                local changes = {
                    dependencies = {
                        remove = { "bd-100", "bd-101" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                assert.same({ "bd", "dep", "remove", "bd-1", "bd-100" }, commands[1])
                assert.same({ "bd", "dep", "remove", "bd-1", "bd-101" }, commands[2])
            end)

            it("should generate commands for both dependency additions and removals", function()
                local changes = {
                    dependencies = {
                        add = { "bd-120" },
                        remove = { "bd-100" },
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(2, #commands)
                -- Removals should come before additions
                assert.same({ "bd", "dep", "remove", "bd-1", "bd-100" }, commands[1])
                assert.same({ "bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks" }, commands[2])
            end)
        end)

        describe("parent operations", function()
            it("should generate command for parent addition", function()
                local changes = {
                    parent = "bd-50",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "dep", "add", "bd-1", "bd-50", "--type", "parent-child" }, commands[1])
            end)

            it("should generate command for parent removal", function()
                local changes = {
                    parent = "", -- Empty string indicates removal
                }
                local original_parent_id = "bd-42"

                local commands = diff.generate_update_commands("bd-1", changes, original_parent_id)

                assert.equals(1, #commands)
                assert.same({ "bd", "dep", "remove", "bd-1", "bd-42" }, commands[1])
            end)

            it("should generate command for parent change", function()
                local changes = {
                    parent = "bd-60", -- Changed from bd-50 to bd-60
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                -- New parent is added (removal of old parent would be handled separately)
                assert.same({ "bd", "dep", "add", "bd-1", "bd-60", "--type", "parent-child" }, commands[1])
            end)
        end)

        describe("special character escaping", function()
            it("should pass single quotes as-is (no escaping needed with tables)", function()
                local changes = {
                    metadata = {
                        title = "Fix user's authentication bug",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                -- With command tables, single quotes don't need escaping
                assert.same({ "bd", "update", "bd-1", "--title", "Fix user's authentication bug" }, commands[1])
            end)

            it("should pass single quotes in description as-is", function()
                local changes = {
                    sections = {
                        description = "The user's session wasn't persisted",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({
                    "bd",
                    "update",
                    "bd-1",
                    "--description",
                    "The user's session wasn't persisted",
                }, commands[1])
            end)

            it("should handle double quotes safely", function()
                local changes = {
                    metadata = {
                        title = 'Add "advanced" search feature',
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                -- Double quotes are passed as-is in command tables
                assert.same({ "bd", "update", "bd-1", "--title", 'Add "advanced" search feature' }, commands[1])
            end)

            it("should handle newlines in text sections", function()
                local changes = {
                    sections = {
                        description = "Line 1\nLine 2\nLine 3",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                -- Newlines are preserved as literal \n characters in the string
                assert.same({ "bd", "update", "bd-1", "--description", "Line 1\nLine 2\nLine 3" }, commands[1])
            end)

            it("should handle special shell characters", function()
                local changes = {
                    metadata = {
                        title = "Fix: $variable expansion & pipe | redirect >",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                -- Special chars should be safe inside single quotes
                assert.same({
                    "bd",
                    "update",
                    "bd-1",
                    "--title",
                    "Fix: $variable expansion & pipe | redirect >",
                }, commands[1])
            end)
        end)

        describe("multiple simultaneous changes", function()
            it("should generate correct command sequence for complex changes", function()
                local changes = {
                    parent = "bd-60",
                    dependencies = {
                        add = { "bd-120" },
                        remove = { "bd-100" },
                    },
                    labels = {
                        add = { "backend" },
                        remove = { "old-label" },
                    },
                    status = "in_progress",
                    metadata = {
                        title = "Updated Title",
                        priority = 1,
                    },
                    sections = {
                        description = "New description",
                    },
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                -- Expected order: parent, deps, labels, status, metadata/sections
                -- Parent: 1 command
                -- Dependencies: 1 remove + 1 add = 2 commands
                -- Labels: 1 remove + 1 add = 2 commands
                -- Status: 1 command
                -- Metadata + sections: 1 combined command
                assert.equals(7, #commands)

                -- Verify order using table assertions
                assert.same({ "bd", "dep", "add", "bd-1", "bd-60", "--type", "parent-child" }, commands[1])
                assert.same({ "bd", "dep", "remove", "bd-1", "bd-100" }, commands[2])
                assert.same({ "bd", "dep", "add", "bd-1", "bd-120", "--type", "blocks" }, commands[3])
                assert.same({ "bd", "label", "remove", "bd-1", "old-label" }, commands[4])
                assert.same({ "bd", "label", "add", "bd-1", "backend" }, commands[5])
                assert.same({ "bd", "update", "bd-1", "--status", "in_progress" }, commands[6])

                -- Command 7 is a combined update with multiple flags - check structure
                local cmd7 = commands[7]
                assert.equals("bd", cmd7[1])
                assert.equals("update", cmd7[2])
                assert.equals("bd-1", cmd7[3])
                -- Check for presence of all expected flags
                local has_title = false
                local has_priority = false
                local has_description = false
                for i = 4, #cmd7, 2 do
                    if cmd7[i] == "--title" then
                        has_title = true
                    end
                    if cmd7[i] == "--priority" then
                        has_priority = true
                    end
                    if cmd7[i] == "--description" then
                        has_description = true
                    end
                end
                assert.is_true(has_title)
                assert.is_true(has_priority)
                assert.is_true(has_description)
            end)
        end)

        describe("edge cases", function()
            it("should return empty array for no changes", function()
                local changes = {}

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.is_table(commands)
                assert.equals(0, #commands)
            end)

            it("should not generate update command with no metadata or section changes", function()
                local changes = {
                    status = "in_progress",
                }

                local commands = diff.generate_update_commands("bd-1", changes, nil)

                assert.equals(1, #commands)
                assert.same({ "bd", "update", "bd-1", "--status", "in_progress" }, commands[1])
            end)
        end)
    end)
end)

--- Tests for search, list, and ready command filter extraction
describe("command filter extraction", function()
    local commands
    local mock_beads
    local mock_constants

    before_each(function()
        env.setup_mock_env()

        -- Mock constants
        mock_constants = {
            STATUSES = {
                open = true,
                closed = true,
                in_progress = true,
                blocked = true,
            },
            ISSUE_TYPES = {
                bug = true,
                feature = true,
                task = true,
                epic = true,
                chore = true,
            },
            PLURAL_MAP = {
                bugs = "bug",
                features = "feature",
                tasks = "task",
                epics = "epic",
                chores = "chore",
            },
        }

        -- Mock beads module
        mock_beads = {
            execute_with_ui = function() end,
        }

        package.loaded["nvim-beads.constants"] = mock_constants
        package.loaded["nvim-beads"] = mock_beads

        -- Load commands module
        package.loaded["nvim-beads.commands"] = nil
        commands = require("nvim-beads.commands")
    end)

    after_each(function()
        env.teardown_mock_env()
    end)

    -- Shared helper function for filter extraction testing
    local function assert_filter_extraction(input_args, expected_bd_args, expected_filter)
        local called_with_bd_args
        local called_with_filter
        mock_beads.execute_with_ui = function(bd_args, filter)
            called_with_bd_args = bd_args
            called_with_filter = filter
        end

        commands.execute({ fargs = input_args })

        assert.same(expected_bd_args, called_with_bd_args)
        assert.same(expected_filter, called_with_filter)
    end

    describe("filter extraction patterns", function()
        local filter_test_cases = {
            -- Search command cases
            {
                name = "search: query without filters",
                input = { "search", "foo", "bar" },
                expected_bd_args = { "search", "foo", "bar" },
                expected_filter = {},
            },
            {
                name = "search: status filter extraction",
                input = { "search", "open", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open" },
            },
            {
                name = "search: type filter extraction",
                input = { "search", "bugs", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { type = "bug" },
            },
            {
                name = "search: plural forms via PLURAL_MAP",
                input = { "search", "features", "authentication" },
                expected_bd_args = { "search", "authentication" },
                expected_filter = { type = "feature" },
            },
            {
                name = "search: combined filters",
                input = { "search", "open", "bugs", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open", type = "bug" },
            },
            {
                name = "search: filters in any order",
                input = { "search", "bugs", "open", "foo" },
                expected_bd_args = { "search", "foo" },
                expected_filter = { status = "open", type = "bug" },
            },
            {
                name = "search: invalid filter treated as query term",
                input = { "search", "invalid", "foo" },
                expected_bd_args = { "search", "invalid", "foo" },
                expected_filter = {},
            },
            -- List command cases
            {
                name = "list: no filters",
                input = { "list" },
                expected_bd_args = { "list" },
                expected_filter = {},
            },
            {
                name = "list: status filter",
                input = { "list", "open" },
                expected_bd_args = { "list" },
                expected_filter = { status = "open" },
            },
            {
                name = "list: type filter",
                input = { "list", "bugs" },
                expected_bd_args = { "list" },
                expected_filter = { type = "bug" },
            },
            {
                name = "list: status and type filters",
                input = { "list", "open", "bugs" },
                expected_bd_args = { "list" },
                expected_filter = { status = "open", type = "bug" },
            },
            -- Ready command cases
            {
                name = "ready: no filters",
                input = { "ready" },
                expected_bd_args = { "ready" },
                expected_filter = {},
            },
            {
                name = "ready: type filter",
                input = { "ready", "features" },
                expected_bd_args = { "ready" },
                expected_filter = { type = "feature" },
            },
        }

        for _, test_case in ipairs(filter_test_cases) do
            it(test_case.name, function()
                assert_filter_extraction(test_case.input, test_case.expected_bd_args, test_case.expected_filter)
            end)
        end
    end)

    describe("search command error handling", function()
        it("errors when no query provided", function()
            local error_shown = false
            _G.vim.notify = function(msg, level)
                if msg:match("query required") and level == vim.log.levels.ERROR then
                    error_shown = true
                end
            end

            commands.execute({ fargs = { "search" } })

            assert.is_true(error_shown)
        end)

        it("errors when only status filter provided", function()
            local error_shown = false
            _G.vim.notify = function(msg, level)
                if msg:match("query required") and level == vim.log.levels.ERROR then
                    error_shown = true
                end
            end

            commands.execute({ fargs = { "search", "open" } })

            assert.is_true(error_shown)
        end)

        it("errors when only type filter provided", function()
            local error_shown = false
            _G.vim.notify = function(msg, level)
                if msg:match("query required") and level == vim.log.levels.ERROR then
                    error_shown = true
                end
            end

            commands.execute({ fargs = { "search", "bugs" } })

            assert.is_true(error_shown)
        end)
    end)
end)

--- Integration tests for execute_with_ui infrastructure
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
end)
