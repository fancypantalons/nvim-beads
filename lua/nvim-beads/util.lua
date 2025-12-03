---@class nvim-beads.util
local M = {}

---Split lines that contain literal newline characters into separate lines
---This handles cases where a single string in an array contains embedded \n characters
---and needs to be split into multiple array elements
---@param lines string[] Array of strings that may contain literal newlines
---@return string[] Array of strings with newlines split into separate elements
function M.split_lines_with_newlines(lines)
    local final_lines = {}
    for _, line in ipairs(lines) do
        if line:find("\n") then
            -- Split on newlines
            local pos = 1
            while true do
                local next_newline = line:find("\n", pos, true)
                if next_newline then
                    table.insert(final_lines, line:sub(pos, next_newline - 1))
                    pos = next_newline + 1
                    -- Check if we're at the end after the newline
                    if pos > #line then
                        -- Trailing newline - add empty string
                        table.insert(final_lines, "")
                        break
                    end
                else
                    -- No more newlines, add rest of string
                    table.insert(final_lines, line:sub(pos))
                    break
                end
            end
        else
            table.insert(final_lines, line)
        end
    end
    return final_lines
end

---Execute a bd command and display the output in a terminal buffer
---This provides clean output similar to vim-fugitive's :Git command
---@param command string The bd subcommand to execute (e.g., 'compact', 'sync')
---@param args string[] Additional arguments to pass to the command
function M.execute_command_in_scratch_buffer(command, args)
    -- Build the shell command string
    local cmd_parts = { "bd", command }
    vim.list_extend(cmd_parts, args or {})

    -- Use vim.fn.shellescape to properly escape each part
    local escaped_parts = vim.tbl_map(vim.fn.shellescape, cmd_parts)
    local shell_cmd = table.concat(escaped_parts, " ")

    -- Open a terminal buffer in a split and run the command
    vim.cmd("split | terminal " .. shell_cmd)

    -- Enter insert mode so the terminal is interactive (if needed)
    -- and resize the split to be smaller
    vim.cmd("resize 10")
    vim.cmd("startinsert")
end

return M
