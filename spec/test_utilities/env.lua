---@class test_utilities.env
---Mock Neovim environment for unit tests
---
---This module provides comprehensive mocking of Neovim's API, notification system,
---and system functions to enable isolated unit testing without a running Neovim instance.
---
---Usage:
---  local env = require("test_utilities.env")
---
---  before_each(function()
---    env.setup_mock_env({
---      expand_cword = "bd-123",  -- Mock vim.fn.expand("<cWORD>")
---      expand_cfile = "test.lua" -- Mock vim.fn.expand("<cfile>")
---    })
---  end)
---
---  after_each(function()
---    env.teardown_mock_env()
---  end)
---
---  it("should notify on error", function()
---    some_function_that_errors()
---    local errors = env.get_error_notifications()
---    assert.equals(1, #errors)
---  end)
local M = {}

local original_vim_api_create_buf
local original_vim_api_set_name
local original_vim_api_set_lines
local original_vim_api_set_option_value
local original_vim_api_set_current_buf
local original_vim_api_win_set_cursor
local original_vim_api_buf_get_number
local original_vim_notify
local original_vim_system
local original_vim_keymap
local original_vim_fn

---Mock state: Buffer number returned by nvim_create_buf
M.created_bufnr = 42

---Mock state: Name set via nvim_buf_set_name
M.buffer_name = nil

---Mock state: Lines set via nvim_buf_set_lines (array of strings)
M.buffer_lines = nil

---Mock state: Buffer-local options set via nvim_set_option_value
---Format: {[bufnr] = {[option] = value}}
M.buffer_options = {}

---Mock state: Current buffer number set via nvim_set_current_buf
M.current_buf = nil

---Mock state: Cursor position set via nvim_win_set_cursor ([line, col])
M.cursor_position = nil

---Mock state: All vim.notify calls captured here
---Format: {{message = "text", level = vim.log.levels.ERROR}, ...}
M.notifications = {}

---Mock state: All vim.system commands captured here
---Format: {{command = {...}, opts = {...}}, ...}
M.system_commands = {}

---Mock state: All vim.keymap.set calls captured here
---Format: {{mode = "n", lhs = "<leader>x", rhs = fn, opts = {...}}, ...}
M.keymaps = {}

---Sets up a mocked Neovim environment for testing
---
---Mocks vim.api buffer functions, vim.notify, vim.system, vim.keymap, and vim.fn.
---All mock state is stored in M.* variables (see module documentation).
---
---@param config? table Optional configuration for vim.fn mocks
---@param config.expand_cword? string Value to return for vim.fn.expand("<cWORD>")
---@param config.expand_cfile? string Value to return for vim.fn.expand("<cfile>")
---
---Example:
---  env.setup_mock_env({expand_cword = "bd-123"})
---  -- Now vim.fn.expand("<cWORD>") returns "bd-123"
function M.setup_mock_env(config)
    -- Save originals
    original_vim_api_create_buf = vim.api.nvim_create_buf
    original_vim_api_set_name = vim.api.nvim_buf_set_name
    original_vim_api_set_lines = vim.api.nvim_buf_set_lines
    original_vim_api_set_option_value = vim.api.nvim_set_option_value
    original_vim_api_set_current_buf = vim.api.nvim_set_current_buf
    original_vim_api_win_set_cursor = vim.api.nvim_win_set_cursor
    original_vim_api_buf_get_number = vim.api.nvim_buf_get_number
    original_vim_notify = vim.notify
    original_vim_system = vim.system
    original_vim_keymap = vim.keymap
    original_vim_fn = vim.fn

    -- Reset mock state
    M.created_bufnr = 42
    M.buffer_name = nil
    M.buffer_lines = nil
    M.buffer_options = {}
    M.current_buf = nil
    M.cursor_position = nil
    M.notifications = {}
    M.system_commands = {}
    M.keymaps = {}

    -- Mock vim.api functions
    vim.api.nvim_create_buf = function(_, _)
        return M.created_bufnr
    end

    vim.api.nvim_buf_set_name = function(_, name)
        M.buffer_name = name
    end

    vim.api.nvim_buf_set_lines = function(_, _, _, _, lines)
        M.buffer_lines = lines
    end

    vim.api.nvim_set_option_value = function(option, value, opts)
        if opts and opts.buf then
            if not M.buffer_options[opts.buf] then
                M.buffer_options[opts.buf] = {}
            end
            M.buffer_options[opts.buf][option] = value
        end
    end

    vim.api.nvim_set_current_buf = function(bufnr)
        M.current_buf = bufnr
    end

    vim.api.nvim_win_set_cursor = function(_, pos)
        M.cursor_position = pos
    end

    vim.api.nvim_buf_get_number = function(name)
        if name == M.buffer_name then
            return M.created_bufnr
        end
        return 0
    end

    vim.api.nvim_buf_is_valid = function(bufnr)
        return bufnr == M.created_bufnr
    end

    vim.api.nvim_buf_delete = function(_, _)
        -- Do nothing, it's a mock
    end

    vim.api.nvim_buf_get_name = function(bufnr)
        if bufnr == M.created_bufnr then
            return M.buffer_name
        end
        return "" -- Or some other default for non-mocked buffers
    end

    vim.api.nvim_buf_get_lines = function(bufnr, _start_row, _end_row, _strict_indexing)
        if bufnr == M.created_bufnr then
            return M.buffer_lines
        end
        return {}
    end

    vim.api.nvim_get_option_value = function(option, opts)
        if option == "modified" and opts and opts.buf == M.created_bufnr then
            return false
        end
        return nil -- Default behavior
    end

    vim.notify = function(msg, level)
        table.insert(M.notifications, { message = msg, level = level })
    end

    -- Mock vim.system
    -- This mock is basic and only records commands.
    -- More sophisticated mocking for specific command outputs can be added if needed.
    vim.system = function(command, opts, on_exit)
        table.insert(M.system_commands, { command = command, opts = opts })
        if on_exit then
            on_exit({ code = 0, signal = 0, stdout = {}, stderr = {} })
        end
        return {
            wait = function()
                return { code = 0, signal = 0, stdout = {}, stderr = {} }
            end,
        }
    end

    -- Mock vim.keymap
    vim.keymap = {
        set = function(mode, lhs, rhs, opts)
            table.insert(M.keymaps, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
        end,
    }

    -- Mock vim.fn
    config = config or {}
    vim.fn = {
        bufnr = function(name)
            if name == M.buffer_name then
                return M.created_bufnr
            end
            return -1
        end,
        expand = function(expr)
            -- Check config for common patterns
            if expr == "<cWORD>" and config.expand_cword then
                return config.expand_cword
            elseif expr == "<cfile>" and config.expand_cfile then
                return config.expand_cfile
            end
            -- Default implementation - returns empty string
            return ""
        end,
    }
end

---Restores the original Neovim functions
---
---Call this in after_each() to clean up after tests
function M.teardown_mock_env()
    vim.api.nvim_create_buf = original_vim_api_create_buf
    vim.api.nvim_buf_set_name = original_vim_api_set_name
    vim.api.nvim_buf_set_lines = original_vim_api_set_lines
    vim.api.nvim_set_option_value = original_vim_api_set_option_value
    vim.api.nvim_set_current_buf = original_vim_api_set_current_buf
    vim.api.nvim_win_set_cursor = original_vim_api_win_set_cursor
    vim.api.nvim_buf_get_number = original_vim_api_buf_get_number
    vim.notify = original_vim_notify
    vim.system = original_vim_system
    vim.keymap = original_vim_keymap
    vim.fn = original_vim_fn
end

---Set the value returned by vim.fn.expand("<cWORD>")
---
---Useful for tests that extract issue IDs from cursor position
---@param word string The word to return (e.g., "bd-123")
---
---Example:
---  env.set_cursor_word("bd-456")
---  assert.equals("bd-456", vim.fn.expand("<cWORD>"))
function M.set_cursor_word(word)
    local original_expand = vim.fn.expand
    vim.fn.expand = function(expr)
        if expr == "<cWORD>" then
            return word
        end
        return original_expand(expr)
    end
end

---Set the value returned by vim.fn.expand("<cfile>")
---
---Useful for tests that extract filenames from cursor position
---@param filename string The filename to return (e.g., "test.lua")
---
---Example:
---  env.set_cursor_file("init.lua")
---  assert.equals("init.lua", vim.fn.expand("<cfile>"))
function M.set_cursor_file(filename)
    local original_expand = vim.fn.expand
    vim.fn.expand = function(expr)
        if expr == "<cfile>" then
            return filename
        end
        return original_expand(expr)
    end
end

---Get all error notifications (vim.log.levels.ERROR)
---@return table[] Array of notification tables with 'message' and 'level' fields
---
---Example:
---  local errors = env.get_error_notifications()
---  assert.equals(1, #errors)
---  assert.matches("Failed to", errors[1].message)
function M.get_error_notifications()
    local errors = {}
    for _, notif in ipairs(M.notifications) do
        if notif.level == vim.log.levels.ERROR then
            table.insert(errors, notif)
        end
    end
    return errors
end

---Get all warning notifications (vim.log.levels.WARN)
---@return table[] Array of notification tables with 'message' and 'level' fields
---
---Example:
---  local warnings = env.get_warning_notifications()
---  assert.equals(0, #warnings)
function M.get_warning_notifications()
    local warnings = {}
    for _, notif in ipairs(M.notifications) do
        if notif.level == vim.log.levels.WARN then
            table.insert(warnings, notif)
        end
    end
    return warnings
end

---Clear all captured notifications
---
---Useful when you need to reset notification state mid-test
---
---Example:
---  some_function() -- might notify
---  env.clear_notifications()
---  another_function()
---  assert.equals(0, #env.notifications) -- only captures notifications after clear
function M.clear_notifications()
    M.notifications = {}
end

return M
