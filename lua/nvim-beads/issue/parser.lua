---@class nvim-beads.issue.parser
local M = {}

---Parse markdown buffer content (YAML frontmatter + Markdown sections) into issue table
---@param buffer_content string[] Array of strings representing buffer lines
---@return table issue Lua table with issue structure
function M.parse_markdown_to_issue(buffer_content)
    local issue = {
        labels = {},
        dependencies = {},
    }

    -- Helper function to trim whitespace
    local function trim(s)
        return s:match("^%s*(.-)%s*$")
    end

    -- Parse YAML frontmatter
    local in_frontmatter = false
    local in_array = nil -- Track which array we're parsing (dependencies, labels, etc.)
    local frontmatter_end = 0

    for i, line in ipairs(buffer_content) do
        if line == "---" then
            if not in_frontmatter then
                in_frontmatter = true
            else
                -- End of frontmatter
                frontmatter_end = i
                break
            end
        elseif in_frontmatter then
            -- Check if this is an array item
            local array_item = line:match("^%s*-%s+(.+)$")
            if array_item and in_array then
                table.insert(issue[in_array], trim(array_item))
            else
                -- Parse key-value pairs (key can contain alphanumeric and underscores)
                local key, value = line:match("^([%w_]+):%s*(.*)$")
                if key then
                    value = trim(value)

                    if key == "type" then
                        -- Map 'type' to 'issue_type'
                        issue.issue_type = value
                    elseif key == "priority" then
                        issue.priority = tonumber(value)
                    elseif key == "closed_at" then
                        if value == "null" or value == "" then
                            issue.closed_at = nil
                        else
                            issue.closed_at = value
                        end
                        in_array = nil
                    elseif key == "dependencies" or key == "labels" then
                        -- Start of array
                        in_array = key
                        if value ~= "" then
                            -- Inline array value (not typical but handle it)
                            table.insert(issue[key], value)
                        end
                    else
                        -- Regular field (including timestamps like created_at, updated_at)
                        issue[key] = value
                        in_array = nil
                    end
                end
            end
        end
    end

    -- Parse Markdown sections
    local current_section = nil
    local section_content = {}

    for i = frontmatter_end + 1, #buffer_content do
        local line = buffer_content[i]

        -- Check if this is a section header
        local section_name = line:match("^# (.+)$")
        if section_name then
            -- Save previous section if exists
            if current_section then
                local content = table.concat(section_content, "\n")
                -- Trim leading/trailing blank lines
                content = content:match("^%s*(.-)%s*$")

                if content ~= "" then
                    issue[current_section] = content
                else
                    issue[current_section] = ""
                end
            end

            -- Start new section
            current_section = section_name:lower():gsub(" ", "_")
            section_content = {}
        elseif current_section and line ~= "" then
            -- Add content to current section (skip empty lines at start)
            if #section_content > 0 or trim(line) ~= "" then
                table.insert(section_content, line)
            end
        elseif current_section and line == "" then
            -- Preserve empty lines within section content
            if #section_content > 0 then
                table.insert(section_content, line)
            end
        end
    end

    -- Save the last section
    if current_section then
        local content = table.concat(section_content, "\n")
        content = content:match("^%s*(.-)%s*$")

        if content ~= "" then
            issue[current_section] = content
        else
            issue[current_section] = ""
        end
    end

    return issue
end

return M
