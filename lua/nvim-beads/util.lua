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

return M
