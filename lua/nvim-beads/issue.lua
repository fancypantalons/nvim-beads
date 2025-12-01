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

  -- Markdown body sections (only include non-empty/non-null sections)

  if issue.description and issue.description ~= "" then
    add_line("# Description")
    add_line("")
    add_line(issue.description)
    add_line("")
  end

  if issue.acceptance_criteria and issue.acceptance_criteria ~= "" then
    add_line("# Acceptance Criteria")
    add_line("")
    add_line(issue.acceptance_criteria)
    add_line("")
  end

  if issue.design and issue.design ~= "" then
    add_line("# Design")
    add_line("")
    add_line(issue.design)
    add_line("")
  end

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
  if not issue_id or type(issue_id) ~= 'string' or issue_id == '' then
    vim.notify('Invalid issue ID', vim.log.levels.ERROR)
    return false
  end

  -- Get the core module for executing bd commands
  local core = require('nvim-beads.core')

  -- Execute bd show command
  local result, err = core.execute_bd({ 'show', issue_id })

  if err then
    vim.notify(
      string.format('Failed to fetch issue %s: %s', issue_id, err),
      vim.log.levels.ERROR
    )
    return false
  end

  -- bd show returns an array with a single issue object
  local issue = nil
  if type(result) == 'table' and #result > 0 then
    issue = result[1]
  end

  if not issue or not issue.id then
    vim.notify(
      string.format('Invalid issue data for %s', issue_id),
      vim.log.levels.ERROR
    )
    return false
  end

  -- Format the issue to markdown
  local lines = M.format_issue_to_markdown(issue)

  -- Split any lines that contain newlines (since nvim_buf_set_lines requires single-line strings)
  local final_lines = {}
  for _, line in ipairs(lines) do
    if line:find('\n') then
      -- Split on newlines
      for subline in line:gmatch('[^\n]+') do
        table.insert(final_lines, subline)
      end
    else
      table.insert(final_lines, line)
    end
  end

  -- Create a new buffer
  local bufnr = vim.api.nvim_create_buf(false, false)

  -- Set buffer name using beads:// URI scheme
  local buffer_name = string.format('beads://issue/%s', issue_id)
  vim.api.nvim_buf_set_name(bufnr, buffer_name)

  -- Populate buffer with formatted content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

  -- Configure buffer options
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'acwrite', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })

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
    dependencies = {}
  }

  -- Helper function to trim whitespace
  local function trim(s)
    return s:match('^%s*(.-)%s*$')
  end

  -- Parse YAML frontmatter
  local in_frontmatter = false
  local in_array = nil  -- Track which array we're parsing (dependencies, labels, etc.)
  local frontmatter_end = 0

  for i, line in ipairs(buffer_content) do
    if line == '---' then
      if not in_frontmatter then
        in_frontmatter = true
      else
        -- End of frontmatter
        frontmatter_end = i
        break
      end
    elseif in_frontmatter then
      -- Check if this is an array item
      local array_item = line:match('^%s*-%s+(.+)$')
      if array_item and in_array then
        table.insert(issue[in_array], trim(array_item))
      else
        -- Parse key-value pairs (key can contain alphanumeric and underscores)
        local key, value = line:match('^([%w_]+):%s*(.*)$')
        if key then
          value = trim(value)

          if key == 'type' then
            -- Map 'type' to 'issue_type'
            issue.issue_type = value
          elseif key == 'priority' then
            issue.priority = tonumber(value)
          elseif key == 'closed_at' then
            if value == 'null' or value == '' then
              issue.closed_at = nil
            else
              issue.closed_at = value
            end
            in_array = nil
          elseif key == 'dependencies' or key == 'labels' then
            -- Start of array
            in_array = key
            if value ~= '' then
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
    local section_name = line:match('^# (.+)$')
    if section_name then
      -- Save previous section if exists
      if current_section then
        local content = table.concat(section_content, '\n')
        -- Trim leading/trailing blank lines
        content = content:match('^%s*(.-)%s*$')

        if content ~= '' then
          issue[current_section] = content
        else
          issue[current_section] = ''
        end
      end

      -- Start new section
      current_section = section_name:lower():gsub(' ', '_')
      section_content = {}
    elseif current_section and line ~= '' then
      -- Add content to current section (skip empty lines at start)
      if #section_content > 0 or trim(line) ~= '' then
        table.insert(section_content, line)
      end
    elseif current_section and line == '' then
      -- Preserve empty lines within section content
      if #section_content > 0 then
        table.insert(section_content, line)
      end
    end
  end

  -- Save the last section
  if current_section then
    local content = table.concat(section_content, '\n')
    content = content:match('^%s*(.-)%s*$')

    if content ~= '' then
      issue[current_section] = content
    else
      issue[current_section] = ''
    end
  end

  return issue
end

return M
