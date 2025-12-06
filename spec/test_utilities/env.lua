local M = {}

local original_vim_api_create_buf
local original_vim_api_set_name
local original_vim_api_set_lines
local original_vim_api_set_option_value
local original_vim_api_set_current_buf
local original_vim_api_win_set_cursor
local original_vim_notify
local original_vim_system

-- Mock state variables
M.created_bufnr = 42
M.buffer_name = nil
M.buffer_lines = nil
M.buffer_options = {}
M.current_buf = nil
M.cursor_position = nil
M.notifications = {}
M.system_commands = {}

--- Sets up a mocked Neovim environment for testing.
-- Mocks `vim.api` functions, `vim.notify`, and `vim.system`.
-- Stores mock state in `M.created_bufnr`, `M.buffer_name`, etc.
function M.setup_mock_env()
    -- Save originals
    original_vim_api_create_buf = vim.api.nvim_create_buf
    original_vim_api_set_name = vim.api.nvim_buf_set_name
    original_vim_api_set_lines = vim.api.nvim_buf_set_lines
    original_vim_api_set_option_value = vim.api.nvim_set_option_value
    original_vim_api_set_current_buf = vim.api.nvim_set_current_buf
    original_vim_api_win_set_cursor = vim.api.nvim_win_set_cursor
    original_vim_notify = vim.notify
    original_vim_system = vim.system

    -- Reset mock state
    M.created_bufnr = 42
    M.buffer_name = nil
    M.buffer_lines = nil
    M.buffer_options = {}
    M.current_buf = nil
    M.cursor_position = nil
    M.notifications = {}
    M.system_commands = {}

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
end

--- Restores the original Neovim functions.
function M.teardown_mock_env()
    vim.api.nvim_create_buf = original_vim_api_create_buf
    vim.api.nvim_buf_set_name = original_vim_api_set_name
    vim.api.nvim_buf_set_lines = original_vim_api_set_lines
    vim.api.nvim_set_option_value = original_vim_api_set_option_value
    vim.api.nvim_set_current_buf = original_vim_api_set_current_buf
    vim.api.nvim_win_set_cursor = original_vim_api_win_set_cursor
    vim.notify = original_vim_notify
    vim.system = original_vim_system
end

return M
