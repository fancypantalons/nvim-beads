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

return M
