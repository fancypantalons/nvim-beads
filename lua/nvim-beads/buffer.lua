---@class nvim-beads.buffer
local M = {}

---Open an issue in a beads:// buffer
---Fetches issue data via 'bd show --json', formats it, and displays in a buffer
---@param issue_id string The issue ID (e.g., "bd-1" or "nvim-beads-p69")
---@return boolean success True if buffer was opened successfully
function M.open_issue_buffer(issue_id)
    -- Validate issue_id
    if not issue_id or type(issue_id) ~= "string" or issue_id == "" then
        vim.notify("Invalid issue ID", vim.log.levels.ERROR)
        return false
    end

    -- Get the core module for executing bd commands
    local core = require("nvim-beads.core")
    local formatter = require("nvim-beads.issue.formatter")

    -- Execute bd show command
    local result, err = core.execute_bd({ "show", issue_id })

    if err then
        vim.notify(string.format("Failed to fetch issue %s: %s", issue_id, err), vim.log.levels.ERROR)
        return false
    end

    -- bd show returns an array with a single issue object
    local issue = nil
    if type(result) == "table" and #result > 0 then
        issue = result[1]
    end

    if not issue or not issue.id then
        vim.notify(string.format("Invalid issue data for %s", issue_id), vim.log.levels.ERROR)
        return false
    end

    -- Format the issue to markdown
    local lines = formatter.format_issue_to_markdown(issue)

    -- Split any lines that contain newlines (since nvim_buf_set_lines requires single-line strings)
    local final_lines = {}
    for _, line in ipairs(lines) do
        if line:find("\n") then
            -- Split on newlines, preserving blank lines
            local pos = 1
            while pos <= #line do
                local next_newline = line:find("\n", pos, true)
                if next_newline then
                    table.insert(final_lines, line:sub(pos, next_newline - 1))
                    pos = next_newline + 1
                else
                    table.insert(final_lines, line:sub(pos))
                    break
                end
            end
        else
            table.insert(final_lines, line)
        end
    end

    -- Set buffer name using beads:// URI scheme
    local buffer_name = string.format("beads://issue/%s", issue_id)

    -- Check if a buffer with this name already exists
    local bufnr = vim.fn.bufnr(buffer_name)
    if bufnr == -1 then
        -- Buffer doesn't exist, create a new one
        bufnr = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(bufnr, buffer_name)

        -- Configure buffer options (only needed for new buffers)
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
        vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
        vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
    end

    -- Populate buffer with formatted content (refresh with latest data)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

    -- Display buffer in current window
    vim.api.nvim_set_current_buf(bufnr)

    return true
end

---Open a new issue buffer for creating a new issue
---Creates a buffer pre-filled with template data in Markdown format with YAML frontmatter
---@param issue_type string The issue type (bug, feature, task, epic, chore)
---@param template_data table The template data from fetch_template
---@return boolean success True if buffer was opened successfully
function M.open_new_issue_buffer(issue_type, template_data)
    local formatter = require("nvim-beads.issue.formatter")

    -- Validate issue_type
    local valid_types = { bug = true, feature = true, task = true, epic = true, chore = true }
    if not issue_type or not valid_types[issue_type] then
        vim.notify("Invalid issue type", vim.log.levels.ERROR)
        return false
    end

    -- Validate template_data
    if not template_data or type(template_data) ~= "table" then
        vim.notify("Invalid template data", vim.log.levels.ERROR)
        return false
    end

    -- Build an issue structure for new issue with template defaults
    local new_issue = {
        id = "(new)",
        title = template_data.title or "",
        issue_type = issue_type,
        status = "open",
        priority = template_data.priority or 2,
        created_at = "null",
        updated_at = "null",
        closed_at = nil,
        assignee = template_data.assignee,
        labels = template_data.labels or {},
        dependencies = {},
        description = template_data.description or "",
        acceptance_criteria = template_data.acceptance_criteria or "",
        design = template_data.design or "",
        notes = template_data.notes or "",
    }

    -- Format the new issue to markdown
    local lines = formatter.format_issue_to_markdown(new_issue)

    -- Split any lines that contain newlines (since nvim_buf_set_lines requires single-line strings)
    local final_lines = {}
    for _, line in ipairs(lines) do
        if line:find("\n") then
            -- Split on newlines, preserving blank lines
            local pos = 1
            while pos <= #line do
                local next_newline = line:find("\n", pos, true)
                if next_newline then
                    table.insert(final_lines, line:sub(pos, next_newline - 1))
                    pos = next_newline + 1
                else
                    table.insert(final_lines, line:sub(pos))
                    break
                end
            end
        else
            table.insert(final_lines, line)
        end
    end

    -- Create a new buffer
    local bufnr = vim.api.nvim_create_buf(false, false)

    -- Set buffer name using beads:// URI scheme for new issues
    local buffer_name = string.format("beads://issue/new?type=%s", issue_type)
    vim.api.nvim_buf_set_name(bufnr, buffer_name)

    -- Populate buffer with formatted content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

    -- Configure buffer options
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })

    -- Display buffer in current window
    vim.api.nvim_set_current_buf(bufnr)

    -- Position cursor on the title field (line 3 in the YAML frontmatter)
    -- Line 1: ---, Line 2: id: (new), Line 3: title: ...
    vim.api.nvim_win_set_cursor(0, { 3, 7 }) -- Position after "title: "

    return true
end

return M
