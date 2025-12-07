--- Core functionality for nvim-beads
--- Provides the main API for interacting with beads issue tracker

local M = {}

--- Commands that should be displayed in Telescope UI
local TELESCOPE_COMMANDS = {
    list = true,
    search = true,
    blocked = true,
    ready = true,
}

--- Prepare bd command arguments by ensuring --json flag is present
---@param args table List of command arguments
---@return table|nil cmd The full command with 'bd' prefix and --json flag, or nil on error
---@return string? error Error message if validation fails
local function prepare_bd_command(args)
    -- Validate arguments
    if type(args) ~= "table" then
        return nil, "prepare_bd_command: args must be a table"
    end

    -- Ensure --json flag is present
    local has_json = false
    for _, arg in ipairs(args) do
        if arg == "--json" then
            has_json = true
            break
        end
    end
    if not has_json then
        table.insert(args, "--json")
    end

    -- Build command with 'bd' prefix
    return vim.list_extend({ "bd" }, args), nil
end

--- Parse and validate bd command result
---@param result table The result from vim.system
---@return table|nil parsed Parsed JSON on success, nil on failure
---@return string? error Error message on failure, nil on success
local function parse_bd_result(result)
    -- Check for command execution errors
    if result.code ~= 0 then
        local stderr = result.stderr
        if not stderr or stderr == "" then
            stderr = "no error output"
        end
        local error_msg = string.format("bd command failed (exit code %d): %s", result.code, stderr)
        return nil, error_msg
    end

    -- Parse JSON output
    local ok, parsed = pcall(vim.json.decode, result.stdout)
    if not ok then
        return nil, string.format("Failed to parse JSON output: %s", parsed)
    end

    return parsed, nil
end

--- Execute a bd command synchronously with JSON output parsing
---@param args table List of command arguments (e.g., {'ready', '--json'})
---@param opts? table Options for vim.system (optional)
---@return table|nil result Parsed JSON result on success, nil on failure
---@return string? error Error message on failure, nil on success
function M.execute_bd(args, opts)
    local cmd, err = prepare_bd_command(args)
    if err then
        return nil, err
    end

    -- Default options: text=true for clean output
    local system_opts = vim.tbl_extend("force", { text = true }, opts or {})

    -- Execute command synchronously
    local result = vim.system(cmd, system_opts):wait()

    return parse_bd_result(result)
end

--- Execute a bd command asynchronously with JSON output parsing
---@param args table List of command arguments (e.g., {'ready'})
---@param callback function Callback function(result: table|nil, error: string|nil)
function M.execute_bd_async(args, callback)
    if type(callback) ~= "function" then
        error("execute_bd_async: callback must be a function")
        return
    end

    local cmd, err = prepare_bd_command(args)
    if err then
        vim.schedule(function()
            callback(nil, err)
        end)
        return
    end

    -- Execute command asynchronously
    vim.system(cmd, { text = true }, function(result)
        vim.schedule(function()
            local parsed, parse_err = parse_bd_result(result)
            callback(parsed, parse_err)
        end)
    end)
end

--- Show ready (unblocked) beads issues
---@param opts table|nil Optional filter options {type, priority, assignee}
function M.show_ready(opts)
    opts = opts or {}

    -- Build bd_args for ready command
    local bd_args = { "ready" }

    -- Build filter table (ready doesn't support all filters server-side)
    local filter = {}
    if opts.type then
        filter.type = opts.type
    end
    if opts.priority then
        filter.priority = opts.priority
    end
    if opts.assignee then
        filter.assignee = opts.assignee
    end

    -- Call show_issues with bd_args and filters
    M.show_issues(bd_args, filter)
end

--- Show list of all beads issues
---@param opts table|nil Optional filter options {status, type, priority, assignee}
function M.show_list(opts)
    opts = opts or {}

    -- Build bd_args from opts
    local bd_args = { "list" }

    -- Build filter table for client-side filtering
    local filter = {}
    if opts.status and opts.status ~= "all" then
        filter.status = opts.status
    end
    if opts.type and opts.type ~= "all" then
        filter.type = opts.type
    end
    if opts.priority then
        filter.priority = opts.priority
    end
    if opts.assignee then
        filter.assignee = opts.assignee
    end

    -- Call show_issues with bd_args and filters
    M.show_issues(bd_args, filter)
end

--- Show issues in Telescope with bd_args and optional filters
---@param bd_args table Array of bd command arguments (e.g., {'list', '--status', 'open'})
---@param opts table|nil Optional table containing filter options and Telescope options
function M.show_issues(bd_args, opts)
    opts = opts or {}

    local has_telescope, telescope = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("nvim-beads: Telescope not found. Install telescope.nvim", vim.log.levels.ERROR)
        return
    end

    -- Load the extension if not already loaded
    if not telescope.extensions.nvim_beads then
        telescope.load_extension("nvim_beads")
    end

    -- Call the telescope show_issues function with bd_args and opts
    telescope.extensions.nvim_beads.show_issues(bd_args, opts)
end

--- Execute bd command with smart UI routing
--- Routes to Telescope for whitelisted commands, otherwise executes in terminal buffer
---@param args table Array of bd command arguments (e.g., {'show', 'bd-123'})
---@param opts table|nil Optional table containing options
function M.execute_with_ui(args, opts)
    opts = opts or {}

    -- Validate args
    if type(args) ~= "table" or #args == 0 then
        vim.notify("execute_with_ui: args must be a non-empty table", vim.log.levels.ERROR)
        return
    end

    local command = args[1]

    -- Check if command should use Telescope UI
    if TELESCOPE_COMMANDS[command] then
        M.show_issues(args, opts)
    else
        -- Execute in terminal buffer
        local util = require("nvim-beads.util")
        local rest_args = vim.list_slice(args, 2)
        util.execute_command_in_scratch_buffer(command, rest_args)
    end
end

--- Fetch template for a given issue type
---@param issue_type string The issue type (bug, feature, task, epic, chore)
---@return table|nil template Parsed template data on success, nil on failure
---@return string? error Error message on failure, nil on success
function M.fetch_template(issue_type)
    -- Validate issue type
    local constants = require("nvim-beads.constants")
    if not constants.ISSUE_TYPES[issue_type] then
        return nil,
            string.format("Invalid issue type '%s'. Must be one of: bug, feature, task, epic, chore", issue_type)
    end

    -- Execute bd template show command
    local result, err = M.execute_bd({ "template", "show", issue_type })
    if err then
        -- Only provide default template if the error is from bd command failure
        -- (template not found), not from JSON parsing errors
        if err:match("bd command failed") then
            -- If no template exists for this type, return a default template
            -- with empty sections for Description, Acceptance Criteria, and Design
            return {
                title = "",
                type = issue_type,
                priority = 2,
                description = "",
                acceptance_criteria = "",
                design = "",
            },
                nil
        else
            -- For other errors (like JSON parsing), propagate the error
            return nil, err
        end
    end

    return result, nil
end

--- Fetches and parses a single issue by its ID.
---@param issue_id string The ID of the issue to fetch.
---@return table? issue The parsed issue object on success.
---@return string? err An error message if fetching or parsing fails.
function M.get_issue(issue_id)
    -- Validate issue_id
    if not issue_id or type(issue_id) ~= "string" or issue_id == "" then
        return nil, "Invalid issue ID"
    end

    -- Execute bd show command
    local result, err = M.execute_bd({ "show", issue_id })
    if err then
        return nil, string.format("Failed to fetch issue %s: %s", issue_id, err)
    end

    -- bd show returns an array with a single issue object
    local issue = nil
    if type(result) == "table" and #result > 0 then
        issue = result[1]
    end

    if not issue or not issue.id then
        return nil, string.format("Invalid issue data for %s", issue_id)
    end

    return issue, nil
end

return M
