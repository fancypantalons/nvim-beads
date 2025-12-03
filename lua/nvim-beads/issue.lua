---@class nvim-beads.issue
local M = {}

---Format an issue table into markdown lines with YAML frontmatter
---@param issue Issue The issue to format
---@return string[] lines Array of strings (one per line) for buffer insertion
function M.format_issue_to_markdown(issue)
    local lines = {}

    -- Helper function to add a line
    local function add_line(line)
        table.insert(lines, line or "")
    end

    -- Start YAML frontmatter
    add_line("---")

    -- Required fields
    add_line("id: " .. issue.id)
    add_line("title: " .. issue.title)

    -- Map issue_type to type for frontmatter
    add_line("type: " .. issue.issue_type)
    add_line("status: " .. issue.status)
    add_line("priority: " .. tostring(issue.priority))

    -- Optional parent field (separate from dependencies)
    -- Look for parent-child dependency in dependencies array
    if issue.dependencies then
        for _, dep in ipairs(issue.dependencies) do
            if dep.dependency_type == "parent-child" then
                add_line("parent: " .. dep.id)
                break
            end
        end
    end

    -- Dependencies (only blocks type, not parent-child)
    if issue.dependencies then
        local deps = {}
        for _, dep in ipairs(issue.dependencies) do
            if dep.dependency_type == "blocks" then
                table.insert(deps, dep.id)
            end
        end
        if #deps > 0 then
            add_line("dependencies:")
            for _, dep_id in ipairs(deps) do
                add_line("  - " .. dep_id)
            end
        end
    end

    -- Optional labels
    if issue.labels and #issue.labels > 0 then
        add_line("labels:")
        for _, label in ipairs(issue.labels) do
            add_line("  - " .. label)
        end
    end

    -- Optional assignee
    if issue.assignee then
        add_line("assignee: " .. issue.assignee)
    end

    -- Timestamp fields
    add_line("created_at: " .. issue.created_at)
    add_line("updated_at: " .. issue.updated_at)
    add_line("closed_at: " .. (issue.closed_at or "null"))

    -- End YAML frontmatter
    add_line("---")
    add_line("")

    -- Markdown body sections
    -- Always show Description, Acceptance Criteria, and Design headers (even if empty)
    -- Only show Notes header if it has content

    -- Description (always shown)
    add_line("# Description")
    add_line("")
    if issue.description and issue.description ~= "" then
        add_line(issue.description)
        add_line("")
    end

    -- Acceptance Criteria (always shown)
    add_line("# Acceptance Criteria")
    add_line("")
    if issue.acceptance_criteria and issue.acceptance_criteria ~= "" then
        add_line(issue.acceptance_criteria)
        add_line("")
    end

    -- Design (always shown)
    add_line("# Design")
    add_line("")
    if issue.design and issue.design ~= "" then
        add_line(issue.design)
        add_line("")
    end

    -- Notes (only shown if non-empty)
    if issue.notes and issue.notes ~= "" then
        add_line("# Notes")
        add_line("")
        add_line(issue.notes)
        add_line("")
    end

    return lines
end

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
    local lines = M.format_issue_to_markdown(issue)

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

    -- Set buffer name using beads:// URI scheme
    local buffer_name = string.format("beads://issue/%s", issue_id)
    vim.api.nvim_buf_set_name(bufnr, buffer_name)

    -- Populate buffer with formatted content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

    -- Configure buffer options
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })

    -- Display buffer in current window
    vim.api.nvim_set_current_buf(bufnr)

    return true
end

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

---Compare two issue states and return structured changes
---@param original table The original issue state (from bd show --json)
---@param modified table The modified issue state (from parse_markdown_to_issue)
---@return table changes Structured table of changes by field type
function M.diff_issues(original, modified)
    local changes = {}

    -- Helper function to convert array to set for efficient lookup
    local function to_set(arr)
        local set = {}
        if arr then
            for _, v in ipairs(arr) do
                set[v] = true
            end
        end
        return set
    end

    -- Helper function to compute set difference (items in a but not in b)
    local function set_difference(a, b)
        local a_set = to_set(a)
        local b_set = to_set(b)
        local diff = {}

        for item, _ in pairs(a_set) do
            if not b_set[item] then
                table.insert(diff, item)
            end
        end

        return #diff > 0 and diff or nil
    end

    -- Helper function to normalize nil and empty string
    local function normalize(value)
        if value == nil or value == "" then
            return nil
        end
        return value
    end

    -- Compare metadata fields (title, priority, assignee)
    local metadata = {}
    local has_metadata_changes = false

    if original.title ~= modified.title then
        metadata.title = modified.title
        has_metadata_changes = true
    end

    if original.priority ~= modified.priority then
        metadata.priority = modified.priority
        has_metadata_changes = true
    end

    -- Handle assignee (can be added, removed, or changed)
    local orig_assignee = normalize(original.assignee)
    local mod_assignee = normalize(modified.assignee)

    if orig_assignee ~= mod_assignee then
        -- Use empty string to indicate removal (since nil means "no change")
        if mod_assignee == nil then
            metadata.assignee = ""
        else
            metadata.assignee = mod_assignee
        end
        has_metadata_changes = true
    end

    if has_metadata_changes then
        changes.metadata = metadata
    end

    -- Compare status
    if original.status ~= modified.status then
        changes.status = modified.status
    end

    -- Compare labels (set-based comparison)
    local orig_labels = original.labels or {}
    local mod_labels = modified.labels or {}

    local labels_added = set_difference(mod_labels, orig_labels)
    local labels_removed = set_difference(orig_labels, mod_labels)

    if labels_added or labels_removed then
        changes.labels = {}
        if labels_added then
            changes.labels.add = labels_added
        end
        if labels_removed then
            changes.labels.remove = labels_removed
        end
    end

    -- Compare dependencies (set-based comparison)
    -- Extract dependency IDs from original (bd show returns objects with id, title, dependency_type)
    -- but parser returns just strings (IDs), and we only want to compare "blocks" type dependencies
    local orig_deps_raw = original.dependencies or {}
    local orig_dep_ids = {}
    for _, dep in ipairs(orig_deps_raw) do
        if type(dep) == "table" then
            -- From bd show --json: filter for "blocks" type only
            if dep.dependency_type == "blocks" then
                table.insert(orig_dep_ids, dep.id)
            end
        else
            -- From tests or other sources: already a string ID
            table.insert(orig_dep_ids, dep)
        end
    end

    local mod_deps = modified.dependencies or {}

    local deps_added = set_difference(mod_deps, orig_dep_ids)
    local deps_removed = set_difference(orig_dep_ids, mod_deps)

    if deps_added or deps_removed then
        changes.dependencies = {}
        if deps_added then
            changes.dependencies.add = deps_added
        end
        if deps_removed then
            changes.dependencies.remove = deps_removed
        end
    end

    -- Compare parent field
    local orig_parent = normalize(original.parent)
    local mod_parent = normalize(modified.parent)

    if orig_parent ~= mod_parent then
        -- Use empty string to indicate removal (since nil means "no change")
        if mod_parent == nil then
            changes.parent = ""
        else
            changes.parent = mod_parent
        end
    end

    -- Compare text sections (description, acceptance_criteria, design, notes)
    local sections = {}
    local section_fields = { "description", "acceptance_criteria", "design", "notes" }

    for _, field in ipairs(section_fields) do
        local orig_value = normalize(original[field])
        local mod_value = modified[field] -- Don't normalize modified value to detect nil -> ''

        -- Detect changes, including nil -> '' and vice versa
        if orig_value ~= mod_value then
            -- Store the modified value (could be '', which is different from nil)
            sections[field] = mod_value or ""
        end
    end

    if next(sections) then
        changes.sections = sections
    end

    return changes
end

---Escape a string for safe use in shell commands
---@param str string The string to escape
---@return string escaped The escaped string suitable for shell command arguments
local function shell_escape(str)
    if not str then
        return '""'
    end

    -- Use single quotes to avoid most shell interpretation
    -- Escape any single quotes by replacing ' with '\''
    local escaped = str:gsub("'", "'\\''")
    return "'" .. escaped .. "'"
end

---Generate bd CLI commands to apply changes from diff_issues
---@param issue_id string The issue ID (e.g., "bd-1")
---@param changes table The changes table from diff_issues()
---@return string[] commands List of bd command strings to execute in order
function M.generate_update_commands(issue_id, changes)
    local commands = {}

    -- Helper to add a command
    local function add_cmd(cmd)
        table.insert(commands, cmd)
    end

    -- Process in order: parent/deps first, then labels, then status, then metadata/text

    -- 1. Handle parent changes (may need to remove old parent first)
    if changes.parent ~= nil then
        if changes.parent == "" then
            -- Parent removed - need to find and remove the old parent-child dependency
            -- Note: The caller will need to know the old parent ID to remove it
            -- For now, we'll just note this in comments - actual removal would require
            -- knowing the original parent ID from the original issue state
            -- This is handled by the caller checking the original.dependencies array
            -- and removing any parent-child type dependencies first
            add_cmd("bd dep remove " .. issue_id .. " <parent-id>")
        else
            -- Parent added or changed
            add_cmd("bd dep add " .. issue_id .. " " .. changes.parent .. " --type parent-child")
        end
    end

    -- 2. Handle dependency changes
    if changes.dependencies then
        -- Remove dependencies first
        if changes.dependencies.remove then
            for _, dep_id in ipairs(changes.dependencies.remove) do
                add_cmd("bd dep remove " .. issue_id .. " " .. dep_id)
            end
        end
        -- Then add new dependencies
        if changes.dependencies.add then
            for _, dep_id in ipairs(changes.dependencies.add) do
                add_cmd("bd dep add " .. issue_id .. " " .. dep_id .. " --type blocks")
            end
        end
    end

    -- 3. Handle label changes
    if changes.labels then
        -- Remove labels first
        if changes.labels.remove then
            for _, label in ipairs(changes.labels.remove) do
                add_cmd("bd label remove " .. issue_id .. " " .. label)
            end
        end
        -- Then add new labels
        if changes.labels.add then
            for _, label in ipairs(changes.labels.add) do
                add_cmd("bd label add " .. issue_id .. " " .. label)
            end
        end
    end

    -- 4. Handle status changes
    if changes.status then
        if changes.status == "closed" then
            add_cmd("bd close " .. issue_id)
        elseif changes.status == "open" then
            add_cmd("bd reopen " .. issue_id)
        else
            -- in_progress or blocked
            add_cmd("bd update " .. issue_id .. " --status " .. changes.status)
        end
    end

    -- 5. Handle metadata and text section changes
    -- We can combine these into a single bd update command with multiple flags
    local update_parts = { "bd update " .. issue_id }

    if changes.metadata then
        if changes.metadata.title then
            table.insert(update_parts, "--title " .. shell_escape(changes.metadata.title))
        end
        if changes.metadata.priority then
            table.insert(update_parts, "--priority " .. tostring(changes.metadata.priority))
        end
        if changes.metadata.assignee ~= nil then
            if changes.metadata.assignee == "" then
                -- Empty string means removal
                table.insert(update_parts, '--assignee ""')
            else
                table.insert(update_parts, "--assignee " .. shell_escape(changes.metadata.assignee))
            end
        end
    end

    if changes.sections then
        if changes.sections.description ~= nil then
            table.insert(update_parts, "--description " .. shell_escape(changes.sections.description))
        end
        if changes.sections.acceptance_criteria ~= nil then
            table.insert(update_parts, "--acceptance " .. shell_escape(changes.sections.acceptance_criteria))
        end
        if changes.sections.design ~= nil then
            table.insert(update_parts, "--design " .. shell_escape(changes.sections.design))
        end
        if changes.sections.notes ~= nil then
            table.insert(update_parts, "--notes " .. shell_escape(changes.sections.notes))
        end
    end

    -- Only add the update command if there are actual updates
    if #update_parts > 1 then
        add_cmd(table.concat(update_parts, " "))
    end

    return commands
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

    -- Format the new issue to markdown
    local lines = M.format_issue_to_markdown(new_issue)

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

---Build bd create command from parsed issue data
---@param parsed_issue table The parsed issue from parse_markdown_to_issue
---@return string|nil command The bd create command string or nil if validation fails
---@return string|nil error Error message if validation fails
function M.build_create_command(parsed_issue)
    -- Validate required fields
    if not parsed_issue.title or parsed_issue.title == "" then
        return nil, "Title is required"
    end

    if not parsed_issue.issue_type or parsed_issue.issue_type == "" then
        return nil, "Issue type is required"
    end

    -- Start building the command
    local parts = { "bd create" }

    -- Add title (required, positional argument)
    table.insert(parts, shell_escape(parsed_issue.title))

    -- Add type (required flag)
    table.insert(parts, "--type " .. parsed_issue.issue_type)

    -- Add optional fields only if populated

    -- Priority
    if parsed_issue.priority then
        table.insert(parts, "--priority " .. tostring(parsed_issue.priority))
    end

    -- Description
    if parsed_issue.description and parsed_issue.description ~= "" then
        table.insert(parts, "--description " .. shell_escape(parsed_issue.description))
    end

    -- Acceptance criteria
    if parsed_issue.acceptance_criteria and parsed_issue.acceptance_criteria ~= "" then
        table.insert(parts, "--acceptance " .. shell_escape(parsed_issue.acceptance_criteria))
    end

    -- Design
    if parsed_issue.design and parsed_issue.design ~= "" then
        table.insert(parts, "--design " .. shell_escape(parsed_issue.design))
    end

    -- Labels (comma-separated)
    if parsed_issue.labels and #parsed_issue.labels > 0 then
        local labels_str = table.concat(parsed_issue.labels, ",")
        table.insert(parts, "--labels " .. shell_escape(labels_str))
    end

    -- Parent
    if parsed_issue.parent and parsed_issue.parent ~= "" then
        table.insert(parts, "--parent " .. parsed_issue.parent)
    end

    -- Dependencies (comma-separated with type prefix)
    if parsed_issue.dependencies and #parsed_issue.dependencies > 0 then
        -- Format as 'blocks:id1,blocks:id2' since these are blocking dependencies
        local deps = {}
        for _, dep_id in ipairs(parsed_issue.dependencies) do
            table.insert(deps, "blocks:" .. dep_id)
        end
        local deps_str = table.concat(deps, ",")
        table.insert(parts, "--deps " .. shell_escape(deps_str))
    end

    return table.concat(parts, " "), nil
end

---Extract issue ID from bd create command JSON output
---@param output string The stdout from bd create --json command
---@return string|nil id The extracted issue ID or nil if extraction fails
---@return string|nil error Error message if extraction fails
function M.extract_id_from_create_output(output)
    -- Validate input
    if not output or output == "" then
        return nil, "Empty output"
    end

    -- Try to decode JSON
    local ok, result = pcall(vim.json.decode, output)
    if not ok then
        return nil, "Failed to parse JSON: " .. tostring(result)
    end

    -- Check if result is a table with id field
    if type(result) ~= "table" then
        return nil, "JSON output is not a table"
    end

    -- Handle vim.NIL (JSON null)
    local id = result.id
    if id == vim.NIL then
        id = nil
    end

    if not id or id == "" then
        return nil, "No id field in JSON output"
    end

    return id, nil
end

return M
