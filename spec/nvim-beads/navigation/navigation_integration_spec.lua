--- Integration tests for navigation workflow

describe("navigation integration", function()
    local navigation
    local buffer_module
    local core_module
    local env = require("test_utilities.env")
    local original_vim_fn
    local original_vim_keymap

    before_each(function()
        -- Clear module cache
        package.loaded["nvim-beads.navigation"] = nil
        package.loaded["nvim-beads.buffer"] = nil
        package.loaded["nvim-beads.core"] = nil

        navigation = require("nvim-beads.navigation")
        buffer_module = require("nvim-beads.buffer")
        core_module = require("nvim-beads.core")

        env.setup_mock_env()

        -- Save originals
        original_vim_fn = vim.fn
        original_vim_keymap = vim.keymap
    end)

    after_each(function()
        env.teardown_mock_env()
        vim.fn = original_vim_fn
        vim.keymap = original_vim_keymap
    end)

    describe("buffer setup with navigation", function()
        it("should set up Enter key mapping when populating beads buffer", function()
            local test_bufnr = 42
            local keymap_configured = false

            -- Mock keymap.set to track configuration
            vim.keymap = {
                set = function(mode, lhs, _rhs, opts)
                    if mode == "n" and lhs == "<CR>" and opts.buffer == test_bufnr then
                        keymap_configured = true
                    end
                end,
            }

            -- Create a mock issue
            local issue = {
                id = "nvim-beads-123",
                title = "Test issue",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2025-11-30T12:00:00Z",
                updated_at = "2025-11-30T12:00:00Z",
                closed_at = nil,
                description = "Test description",
                labels = {},
                dependencies = {},
            }

            -- Call populate_beads_buffer
            buffer_module.populate_beads_buffer(test_bufnr, issue)

            -- Verify keymap was set up
            assert.is_true(keymap_configured)
        end)
    end)

    describe("end-to-end navigation workflow", function()
        it("should navigate from one issue to another via Enter key", function()
            -- Setup: Mock repository with two issues
            local issue_database = {
                ["nvim-beads-123"] = {
                    id = "nvim-beads-123",
                    title = "Parent issue",
                    issue_type = "epic",
                    status = "open",
                    priority = 1,
                    created_at = "2025-11-30T12:00:00Z",
                    updated_at = "2025-11-30T12:00:00Z",
                    closed_at = nil,
                    description = "This is the parent epic",
                    labels = {},
                    dependencies = {},
                },
                ["nvim-beads-456"] = {
                    id = "nvim-beads-456",
                    title = "Child issue",
                    issue_type = "task",
                    status = "open",
                    priority = 2,
                    created_at = "2025-11-30T12:00:00Z",
                    updated_at = "2025-11-30T12:00:00Z",
                    closed_at = nil,
                    description = "References parent: nvim-beads-123",
                    labels = {},
                    dependencies = {
                        { id = "nvim-beads-123", dependency_type = "parent-child" },
                    },
                },
            }

            -- Mock bd commands
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    -- Return any issue for prefix detection
                    return { { id = "nvim-beads-123" } }, nil
                elseif args[1] == "show" then
                    local issue_id = args[2]
                    if issue_database[issue_id] then
                        return { issue_database[issue_id] }, nil
                    end
                    return nil, "Issue not found"
                end
                return nil, "Unknown command"
            end

            -- Mock cursor on issue ID in the description
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-123"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            -- Track buffer operations
            local opened_issues = {}
            local original_open_buffer = buffer_module.open_issue_buffer
            buffer_module.open_issue_buffer = function(issue_id)
                table.insert(opened_issues, issue_id)
                return original_open_buffer(issue_id)
            end

            -- Execute navigation
            local success = navigation.navigate_to_issue_at_cursor()

            -- Verify
            assert.is_true(success)
            assert.equals(1, #opened_issues)
            assert.equals("nvim-beads-123", opened_issues[1])

            -- Verify buffer was created with correct name
            assert.equals("beads://issue/nvim-beads-123", env.buffer_name)
        end)

        it("should work with issue references in YAML frontmatter", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-abc" } }, nil
                elseif args[1] == "show" and args[2] == "nvim-beads-parent" then
                    return {
                        {
                            id = "nvim-beads-parent",
                            title = "Parent epic",
                            issue_type = "epic",
                            status = "open",
                            priority = 1,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Parent issue",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Unknown command"
            end

            -- Cursor on parent field in YAML
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-parent"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_true(success)
            assert.equals("beads://issue/nvim-beads-parent", env.buffer_name)
        end)

        it("should work with issue references in dependency lists", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-def" } }, nil
                elseif args[1] == "show" and args[2] == "nvim-beads-dep" then
                    return {
                        {
                            id = "nvim-beads-dep",
                            title = "Dependency",
                            issue_type = "task",
                            status = "in_progress",
                            priority = 1,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Dependency task",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Unknown command"
            end

            -- Cursor on dependency in list (with leading dash)
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "-nvim-beads-dep"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_true(success)
            assert.equals("beads://issue/nvim-beads-dep", env.buffer_name)
        end)

        it("should handle navigation failure when issue does not exist", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-xyz" } }, nil
                elseif args[1] == "show" then
                    return nil, "Issue not found"
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-nonexistent"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            local success = navigation.navigate_to_issue_at_cursor()

            -- Navigation should report failure (buffer.open_issue_buffer returns false)
            assert.is_false(success)

            -- Verify error notification was sent
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)
        end)
    end)

    describe("public API - show_under_cursor in regular buffers", function()
        local init_module

        before_each(function()
            package.loaded["nvim-beads"] = nil
            init_module = require("nvim-beads")
        end)

        it("should work in a regular markdown buffer", function()
            -- Setup repository with an issue
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-abc" } }, nil
                elseif args[1] == "show" and args[2] == "nvim-beads-doc" then
                    return {
                        {
                            id = "nvim-beads-doc",
                            title = "Documentation task",
                            issue_type = "task",
                            status = "open",
                            priority = 2,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Add documentation",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Unknown command"
            end

            -- Simulate cursor in a regular markdown file mentioning an issue
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        -- Cursor on "See nvim-beads-doc for details"
                        return "nvim-beads-doc"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            -- Call public API
            local success = init_module.show_under_cursor()

            assert.is_true(success)
            assert.equals("beads://issue/nvim-beads-doc", env.buffer_name)
        end)

        it("should work in a code file with comment reference", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-bug" } }, nil
                elseif args[1] == "show" and args[2] == "nvim-beads-bug" then
                    return {
                        {
                            id = "nvim-beads-bug",
                            title = "Fix the thing",
                            issue_type = "bug",
                            status = "in_progress",
                            priority = 1,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Bug details",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Unknown command"
            end

            -- Simulate cursor in code comment like "-- TODO: see nvim-beads-bug"
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-bug"
                    end
                    return ""
                end,
                bufnr = function(name)
                    if name == env.buffer_name then
                        return env.created_bufnr
                    end
                    return -1
                end,
            }

            local success = init_module.show_under_cursor()

            assert.is_true(success)
            assert.equals("beads://issue/nvim-beads-bug", env.buffer_name)
        end)

        it("should notify when no issue found and notify_on_miss is true", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-test" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "not-an-issue-id"
                    end
                    return ""
                end,
                bufnr = function(_name)
                    return -1
                end,
            }

            local success = init_module.show_under_cursor({ notify_on_miss = true })

            assert.is_false(success)

            -- Verify warning notification was sent
            local found_warning = false
            for _, notif in ipairs(env.notifications) do
                if notif.level == vim.log.levels.WARN and notif.message == "No issue ID found under cursor" then
                    found_warning = true
                    break
                end
            end
            assert.is_true(found_warning)
        end)

        it("should not notify when no issue found and notify_on_miss is false", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-test" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "not-an-issue-id"
                    end
                    return ""
                end,
                bufnr = function(_name)
                    return -1
                end,
            }

            -- Clear notifications
            env.notifications = {}

            local success = init_module.show_under_cursor({ notify_on_miss = false })

            assert.is_false(success)

            -- Should have no warning notifications
            local found_warning = false
            for _, notif in ipairs(env.notifications) do
                if notif.level == vim.log.levels.WARN and notif.message == "No issue ID found under cursor" then
                    found_warning = true
                    break
                end
            end
            assert.is_false(found_warning)
        end)
    end)
end)
