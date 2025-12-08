---@class test_utilities.factory
---Test data factory for creating issues, commands, and dependencies
---
---This module provides factory functions to reduce boilerplate in test setup.
---Instead of manually constructing issue objects with all required fields,
---use these factories to create valid test data with sensible defaults.
---
---Key features:
--- - Auto-incrementing IDs for uniqueness
--- - Sensible defaults for all required fields
--- - Easy overrides via table parameter
--- - Shorthand helpers for common variations
---
---Usage:
---  local factory = require("test_utilities.factory")
---
---  -- Create a basic issue
---  local issue = factory.issue()
---
---  -- Create an issue with overrides
---  local bug = factory.bug({
---    title = "Specific bug title",
---    priority = 0
---  })
---
---  -- Create a bd command
---  local cmd = factory.bd_command("update", "bd-123", {
---    ["--title"] = "New Title",
---    ["--priority"] = "1"
---  })
local M = {}

-- Counter for auto-incrementing test IDs
local _id_counter = 0

---Reset the ID counter (useful for test isolation)
---
---Call this in before_each if you need predictable IDs across tests.
---
---Example:
---  before_each(function()
---    factory.reset_counter()
---  end)
function M.reset_counter()
    _id_counter = 0
end

---Get next unique test ID
---
---@return string id Auto-incremented ID like "test-1", "test-2", etc.
local function next_id()
    _id_counter = _id_counter + 1
    return "test-" .. _id_counter
end

---Create a test issue with sensible defaults
---
---Returns a fully-populated issue object with all required fields.
---All fields can be overridden via the overrides parameter.
---
---@param overrides? table Fields to override in the default issue
---@return table issue Complete issue object ready for testing
---
---Example:
---  local issue = factory.issue({
---    title = "My test issue",
---    status = "closed",
---    priority = 0
---  })
---  -- Returns issue with overridden fields plus all defaults
function M.issue(overrides)
    overrides = overrides or {}

    local defaults = {
        id = next_id(),
        title = "Test Issue",
        issue_type = "task",
        status = "open",
        priority = 2,
        created_at = "2025-01-01T00:00:00Z",
        updated_at = "2025-01-01T00:00:00Z",
        closed_at = nil,
        description = "",
        acceptance_criteria = "",
        design = "",
        notes = "",
        labels = {},
        dependencies = {},
        external_ref = nil,
        assignee = nil,
    }

    -- Merge overrides into defaults
    for key, value in pairs(overrides) do
        defaults[key] = value
    end

    return defaults
end

---Create an open issue (shorthand for issue with status="open")
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with status="open"
---
---Example:
---  local issue = factory.open_issue({title = "Open bug"})
function M.open_issue(overrides)
    overrides = overrides or {}
    overrides.status = "open"
    return M.issue(overrides)
end

---Create a closed issue (shorthand for issue with status="closed")
---
---Automatically sets closed_at timestamp unless overridden.
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with status="closed"
---
---Example:
---  local issue = factory.closed_issue({title = "Completed task"})
function M.closed_issue(overrides)
    overrides = overrides or {}
    overrides.status = "closed"
    if overrides.closed_at == nil then
        overrides.closed_at = "2025-01-02T00:00:00Z"
    end
    return M.issue(overrides)
end

---Create a bug issue (shorthand for issue with issue_type="bug")
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with issue_type="bug"
---
---Example:
---  local bug = factory.bug({title = "Critical bug", priority = 0})
function M.bug(overrides)
    overrides = overrides or {}
    overrides.issue_type = "bug"
    return M.issue(overrides)
end

---Create a feature issue (shorthand for issue with issue_type="feature")
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with issue_type="feature"
---
---Example:
---  local feature = factory.feature({title = "New feature"})
function M.feature(overrides)
    overrides = overrides or {}
    overrides.issue_type = "feature"
    return M.issue(overrides)
end

---Create a task issue (shorthand for issue with issue_type="task")
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with issue_type="task"
---
---Example:
---  local task = factory.task({title = "Refactor tests"})
function M.task(overrides)
    overrides = overrides or {}
    overrides.issue_type = "task"
    return M.issue(overrides)
end

---Create an epic issue (shorthand for issue with issue_type="epic")
---
---@param overrides? table Additional fields to override
---@return table issue Issue object with issue_type="epic"
---
---Example:
---  local epic = factory.epic({title = "Q1 Goals"})
function M.epic(overrides)
    overrides = overrides or {}
    overrides.issue_type = "epic"
    return M.issue(overrides)
end

---Create a bd command table
---
---Constructs a command array in the format used by bd CLI.
---Flags are provided as a table and converted to positional arguments.
---
---@param subcommand string BD subcommand (e.g., "update", "create", "close")
---@param issue_id? string Optional issue ID (appears after subcommand)
---@param flags? table Optional map of flag names to values {["--flag"] = "value"}
---@return table command Array in format {"bd", subcommand, issue_id?, ...flags}
---
---Example:
---  local cmd = factory.bd_command("update", "bd-123", {
---    ["--title"] = "New Title",
---    ["--priority"] = "1",
---    ["--status"] = "in_progress"
---  })
---  -- Returns: {"bd", "update", "bd-123", "--title", "New Title", "--priority", "1", "--status", "in_progress"}
function M.bd_command(subcommand, issue_id, flags)
    local cmd = { "bd", subcommand }

    -- Add issue_id if provided
    if issue_id then
        table.insert(cmd, issue_id)
    end

    -- Add flags if provided
    if flags then
        for flag, value in pairs(flags) do
            table.insert(cmd, flag)
            table.insert(cmd, tostring(value))
        end
    end

    return cmd
end

---Create a dependency object
---
---Creates a dependency relationship between two issues.
---Defaults to "blocks" type unless overridden.
---
---@param from_id string The issue that depends on another
---@param to_id string The issue that is depended upon
---@param dep_type? string Type of dependency (default: "blocks")
---@return table dependency Dependency object with from_id, to_id, and type
---
---Example:
---  local dep = factory.dependency("bd-1", "bd-2", "blocks")
---  -- Returns: {from_id = "bd-1", to_id = "bd-2", type = "blocks"}
---
---  local related = factory.dependency("bd-3", "bd-4", "related")
---  -- Returns: {from_id = "bd-3", to_id = "bd-4", type = "related"}
function M.dependency(from_id, to_id, dep_type)
    return {
        from_id = from_id,
        to_id = to_id,
        type = dep_type or "blocks",
    }
end

return M
