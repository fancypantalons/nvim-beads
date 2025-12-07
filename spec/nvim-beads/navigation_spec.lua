--- Unit tests for navigation module

describe("navigation", function()
    local navigation
    local core_module
    local buffer_module
    local original_vim_fn
    local original_vim_keymap

    before_each(function()
        -- Clear module cache
        package.loaded["nvim-beads.navigation"] = nil
        package.loaded["nvim-beads.core"] = nil
        package.loaded["nvim-beads.buffer"] = nil

        navigation = require("nvim-beads.navigation")
        core_module = require("nvim-beads.core")
        buffer_module = require("nvim-beads.buffer")

        -- Save originals
        original_vim_fn = vim.fn
        original_vim_keymap = vim.keymap
    end)

    after_each(function()
        -- Restore originals
        vim.fn = original_vim_fn
        vim.keymap = original_vim_keymap
    end)

    describe("navigate_to_issue_at_cursor", function()
        it("should extract and navigate to issue ID under cursor", function()
            -- Mock prefix detection
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-123" } }, nil
                end
                return nil, "Unknown command"
            end

            -- Mock cursor word extraction
            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-5ia"
                    end
                    return ""
                end,
            }

            -- Track if open_issue_buffer was called
            local opened_issue_id = nil
            buffer_module.open_issue_buffer = function(issue_id)
                opened_issue_id = issue_id
                return true
            end

            -- Call navigation
            local success = navigation.navigate_to_issue_at_cursor()

            -- Verify
            assert.is_true(success)
            assert.equals("nvim-beads-5ia", opened_issue_id)
        end)

        it("should extract issue ID from YAML list syntax", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-abc" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        -- Cursor on line like "  - nvim-beads-5ia"
                        return "-nvim-beads-5ia"
                    end
                    return ""
                end,
            }

            local opened_issue_id = nil
            buffer_module.open_issue_buffer = function(issue_id)
                opened_issue_id = issue_id
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_true(success)
            assert.equals("nvim-beads-5ia", opened_issue_id)
        end)

        it("should extract issue ID from YAML field value", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-xyz" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        -- Cursor on line like "parent: nvim-beads-42"
                        return "nvim-beads-42"
                    end
                    return ""
                end,
            }

            local opened_issue_id = nil
            buffer_module.open_issue_buffer = function(issue_id)
                opened_issue_id = issue_id
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_true(success)
            assert.equals("nvim-beads-42", opened_issue_id)
        end)

        it("should handle non-issue text gracefully", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-123" } }, nil
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
            }

            local buffer_opened = false
            buffer_module.open_issue_buffer = function(_issue_id)
                buffer_opened = true
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            -- Should fail silently
            assert.is_false(success)
            assert.is_false(buffer_opened)
        end)

        it("should handle empty cursor position", function()
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "nvim-beads-123" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return ""
                    end
                    return ""
                end,
            }

            local buffer_opened = false
            buffer_module.open_issue_buffer = function(_issue_id)
                buffer_opened = true
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_false(success)
            assert.is_false(buffer_opened)
        end)

        it("should handle prefix detection failure gracefully", function()
            -- Mock prefix detection to fail
            core_module.execute_bd = function(_args)
                return nil, "bd command failed"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "nvim-beads-5ia"
                    end
                    return ""
                end,
            }

            -- Mock notifications
            local notifications = {}
            local original_notify = vim.notify
            vim.notify = function(msg, level)
                table.insert(notifications, { message = msg, level = level })
            end

            local buffer_opened = false
            buffer_module.open_issue_buffer = function(_issue_id)
                buffer_opened = true
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            -- Restore notify
            vim.notify = original_notify

            assert.is_false(success)
            assert.is_false(buffer_opened)
            -- Should have warning about prefix detection failure
            assert.is_true(#notifications > 0)
        end)

        it("should handle special characters in prefix", function()
            -- Test with prefix that has special regex characters
            core_module.execute_bd = function(args)
                if args[1] == "list" then
                    return { { id = "my-project.test-123" } }, nil
                end
                return nil, "Unknown command"
            end

            vim.fn = {
                expand = function(expr)
                    if expr == "<cWORD>" then
                        return "my-project.test-5ia"
                    end
                    return ""
                end,
            }

            local opened_issue_id = nil
            buffer_module.open_issue_buffer = function(issue_id)
                opened_issue_id = issue_id
                return true
            end

            local success = navigation.navigate_to_issue_at_cursor()

            assert.is_true(success)
            assert.equals("my-project.test-5ia", opened_issue_id)
        end)
    end)

    describe("setup_buffer_keymaps", function()
        it("should set buffer-local Enter key mapping", function()
            local test_bufnr = 42
            local keymap_set = false
            local captured_opts = nil

            vim.keymap = {
                set = function(mode, lhs, _rhs, opts)
                    if mode == "n" and lhs == "<CR>" and opts.buffer == test_bufnr then
                        keymap_set = true
                        captured_opts = opts
                    end
                end,
            }

            navigation.setup_buffer_keymaps(test_bufnr)

            assert.is_true(keymap_set)
            assert.equals(test_bufnr, captured_opts.buffer)
            assert.is_true(captured_opts.silent)
            assert.equals("Navigate to issue under cursor", captured_opts.desc)
        end)
    end)
end)
