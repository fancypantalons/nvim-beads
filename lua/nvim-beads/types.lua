---@meta

---Dependency relationship between issues
---@class Dependency
---@field id string Issue ID that this dependency points to
---@field title string Title of the dependent issue
---@field dependency_type "blocks"|"related"|"parent-child"|"discovered-from" Type of dependency relationship

---Main issue type matching bd show --json output
---@class Issue
---@field id string Unique issue identifier (e.g., "nvim-beads-123")
---@field title string Issue title
---@field description string|nil Issue description
---@field design string|nil Design notes and implementation approach
---@field acceptance_criteria string|nil Acceptance criteria for completion
---@field notes string|nil Additional notes
---@field status "open"|"in_progress"|"blocked"|"closed" Current issue status
---@field priority integer Priority level (0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog)
---@field issue_type "bug"|"feature"|"task"|"epic"|"chore" Type of issue
---@field assignee string|nil Person assigned to this issue
---@field labels string[]|nil List of labels/tags
---@field created_at string ISO 8601 timestamp when issue was created
---@field updated_at string ISO 8601 timestamp when issue was last updated
---@field closed_at string|nil ISO 8601 timestamp when issue was closed
---@field external_ref string|nil External reference (e.g., GitHub issue number)
---@field dependencies Dependency[]|nil Issues that this issue depends on
---@field dependents Dependency[]|nil Issues that depend on this issue
---@field dependency_count integer|nil Number of dependencies (blocking this issue)
---@field dependent_count integer|nil Number of dependents (blocked by this issue)

local M = {}

return M
