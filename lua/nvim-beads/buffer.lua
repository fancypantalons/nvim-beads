---@class nvim-beads.buffer
local M = {}

---Populate a buffer with issue content and set standard options for beads
---@param bufnr number The buffer number to populate
---@param issue table The issue object to format and display
function M.populate_beads_buffer(bufnr, issue)
    local formatter = require("nvim-beads.issue.formatter")
    local util = require("nvim-beads.util")

    -- Format the issue to markdown
    local lines = formatter.format_issue_to_markdown(issue)

    -- Split any lines that contain newlines
    local final_lines = util.split_lines_with_newlines(lines)

    -- Populate buffer with formatted content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

    -- Configure buffer options
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

---Open an issue in a beads:// buffer
---Fetches issue data via 'bd show --json', formats it, and displays in a buffer
---@param issue_id string The issue ID (e.g., "bd-1" or "nvim-beads-p69")
---@return boolean success True if buffer was opened successfully
function M.open_issue_buffer(issue_id)
    local core = require("nvim-beads.core")
    local issue, err = core.get_issue(issue_id)

    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    -- Set buffer name using beads:// URI scheme
    local buffer_name = string.format("beads://issue/%s", issue_id)

    -- Check if a buffer with this name already exists
    local bufnr = vim.fn.bufnr(buffer_name)
    if bufnr == -1 then
        -- Buffer doesn't exist, create a new one
        bufnr = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(bufnr, buffer_name)
    end

    -- Populate buffer and set options
    M.populate_beads_buffer(bufnr, issue)

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

    -- Create a new buffer
    local bufnr = vim.api.nvim_create_buf(false, false)

    -- Set buffer name using beads:// URI scheme for new issues
    local buffer_name = string.format("beads://issue/new?type=%s", issue_type)
    vim.api.nvim_buf_set_name(bufnr, buffer_name)

    -- Populate buffer and set options
    M.populate_beads_buffer(bufnr, new_issue)

    -- Display buffer in current window
    vim.api.nvim_set_current_buf(bufnr)

    -- Position cursor on the title field (line 3 in the YAML frontmatter)
    -- Line 1: ---, Line 2: id: (new), Line 3: title: ...
    vim.api.nvim_win_set_cursor(0, { 3, 7 }) -- Position after "title: "

    return true
end

--- Reloads a buffer with the authoritative content of an issue from bd
---@param bufnr number The buffer number to update
---@param issue_id string The ID of the issue to fetch
---@return boolean success True if the buffer was reloaded successfully
function M.reload_buffer_from_issue_id(bufnr, issue_id)
    local core = require("nvim-beads.core")
    local issue, err = core.get_issue(issue_id)

    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    -- Delegate buffer population to the new helper
    M.populate_beads_buffer(bufnr, issue)

    return true
end

return M
