--- Public Lua API for nvim-beads
--- This is the canonical interface for programmatic access to nvim-beads functionality.
--- Users should call these functions instead of directly accessing internal modules.

local M = {}

--- Normalize and validate opts table
---@param opts table|nil The options table
---@return table Normalized options with defaults applied
local function normalize_opts(opts)
    return opts or {}
end

--- List issues with optional filters
---@param opts table|nil Filter options:
---   - status (string): Filter by status - "open", "in_progress", "blocked", "closed", "ready", "stale", "all"
---   - type (string): Filter by type - "bug", "feature", "task", "epic", "chore", "all"
---   - priority (number): Filter by priority - 0-4
---   - assignee (string): Filter by assignee
function M.list(opts)
    opts = normalize_opts(opts)
    local core = require("nvim-beads.core")
    core.show_list(opts)
end

--- Show a specific issue by ID in an read/write buffer
---@param issue_id string The ID of the issue to show
---@param opts table|nil Reserved for future options
function M.show(issue_id)
    -- Validate issue_id
    if not issue_id or type(issue_id) ~= "string" or issue_id == "" then
        vim.notify("nvim-beads.show: issue_id is required and must be a non-empty string", vim.log.levels.ERROR)
        return
    end

    local buffer = require("nvim-beads.buffer")
    buffer.open_issue_buffer(issue_id)
end

--- Open a new buffer for creating an issue of the specified type, using the
--- given template or, if none is specified, the configured template in 'bd'
--- for that issue type.
---@param opts table|nil Options:
---   - type (string): Issue type - "bug", "feature", "task", "epic", "chore" (default: "task")
---   - template (table): Pre-populated template data
function M.create(opts)
    opts = normalize_opts(opts)

    local issue_type = opts.type or "task"
    local template = opts.template

    -- Validate issue type
    local constants = require("nvim-beads.constants")
    if not constants.ISSUE_TYPES[issue_type] then
        vim.notify(
            string.format(
                "nvim-beads.create: invalid issue type '%s'. Must be one of: bug, feature, task, epic, chore",
                issue_type
            ),
            vim.log.levels.ERROR
        )
        return
    end

    -- If no template provided, fetch the default template for this type
    if not template then
        local core = require("nvim-beads.core")
        local fetched_template, err = core.fetch_template(issue_type)
        if err then
            vim.notify("nvim-beads.create: " .. err, vim.log.levels.ERROR)
            return
        end
        template = fetched_template
    end

    local buffer = require("nvim-beads.buffer")
    local success = buffer.open_new_issue_buffer(issue_type, template)

    if not success then
        vim.notify("nvim-beads.create: Failed to create issue buffer", vim.log.levels.ERROR)
    end
end

--- Convenience function to show ready (unblocked) issues with optional
--- filters. This is equivalent to called 'list' filtering on issues in the
--- 'ready' pseudo-state.
---@param opts table|nil Same filter options as list()
function M.ready(opts)
    opts = normalize_opts(opts)
    local core = require("nvim-beads.core")
    core.show_ready(opts)
end

--- Excute an arbitrary bd command. All arguments are passed straight to 'bd'.
---@param args table Array of bd command arguments (e.g., {"show", "bd-123"})
---@param opts table|nil Options:
---   - async (boolean): If true, execute asynchronously (default: false)
---   - callback (function): Callback for async execution: function(result, error)
---@return table|nil result Parsed JSON result (sync) or nil (async)
function M.execute(args, opts)
    opts = normalize_opts(opts)

    -- Validate args
    if not args or type(args) ~= "table" then
        local err_msg = "nvim-beads.execute: args must be a table"
        if opts.async and opts.callback then
            vim.schedule(function()
                opts.callback(nil, err_msg)
            end)
            return nil
        else
            error(err_msg)
        end
    end

    local core = require("nvim-beads.core")

    if opts.async then
        if not opts.callback or type(opts.callback) ~= "function" then
            error("nvim-beads.execute: callback required for async execution")
        end
        core.execute_bd_async(args, opts.callback)
        return nil
    else
        return core.execute_bd(args, opts)
    end
end

--- Execute a bd command with smart UI routing.
--- Whitelisted commands (list, search, blocked, ready) display in Telescope.
--- Other commands execute in a terminal buffer.
---@param args table Array of bd command arguments (e.g., {"list", "--priority", "1"})
---@param opts table|nil Options (reserved for future use)
function M.execute_with_ui(args, opts)
    opts = normalize_opts(opts)

    -- Validate args
    if not args or type(args) ~= "table" or #args == 0 then
        vim.notify("nvim-beads.execute_with_ui: args must be a non-empty table", vim.log.levels.ERROR)
        return
    end

    local core = require("nvim-beads.core")
    core.execute_with_ui(args, opts)
end

return M
