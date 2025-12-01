--- Core functionality for nvim-beads
--- Provides the main API for interacting with beads issue tracker

local M = {}

--- Execute a bd command asynchronously with JSON output parsing
---@param args table List of command arguments (e.g., {'ready', '--json'})
---@param opts? table Options for vim.system (optional)
---@return table|nil result Parsed JSON result on success, nil on failure
---@return string? error Error message on failure, nil on success
function M.execute_bd(args, opts)
    -- Validate arguments
    if type(args) ~= 'table' then
        return nil, 'execute_bd: args must be a table'
    end

    -- Ensure --json flag is present
    local has_json = false
    for _, arg in ipairs(args) do
        if arg == '--json' then
            has_json = true
            break
        end
    end
    if not has_json then
        table.insert(args, '--json')
    end

    -- Build command
    local cmd = vim.list_extend({'bd'}, args)

    -- Default options: text=true for clean output
    local system_opts = vim.tbl_extend('force', {text = true}, opts or {})

    -- Execute command synchronously
    local result = vim.system(cmd, system_opts):wait()

    -- Check for command execution errors
    if result.code ~= 0 then
        local stderr = result.stderr
        if not stderr or stderr == '' then
            stderr = 'no error output'
        end
        local error_msg = string.format(
            'bd command failed (exit code %d): %s',
            result.code,
            stderr
        )
        return nil, error_msg
    end

    -- Parse JSON output
    local ok, parsed = pcall(vim.json.decode, result.stdout)
    if not ok then
        return nil, string.format('Failed to parse JSON output: %s', parsed)
    end

    return parsed, nil
end

--- Show ready (unblocked) beads issues
function M.show_ready()
    -- TODO: Implement show_ready functionality
    vim.notify("nvim-beads: show_ready not yet implemented", vim.log.levels.INFO)
end

--- Show list of all beads issues
function M.show_list()
    -- TODO: Implement show_list functionality
    vim.notify("nvim-beads: show_list not yet implemented", vim.log.levels.INFO)
end

--- Fetch template for a given issue type
---@param issue_type string The issue type (bug, feature, task, epic, chore)
---@return table|nil template Parsed template data on success, nil on failure
---@return string? error Error message on failure, nil on success
function M.fetch_template(issue_type)
    -- Validate issue type
    local valid_types = {bug = true, feature = true, task = true, epic = true, chore = true}
    if not valid_types[issue_type] then
        return nil, string.format("Invalid issue type '%s'. Must be one of: bug, feature, task, epic, chore", issue_type)
    end

    -- Execute bd template show command
    local result, err = M.execute_bd({'template', 'show', issue_type})
    if err then
        return nil, err
    end

    return result, nil
end

--- Create a new beads issue
function M.create_issue()
    -- TODO: Implement create_issue functionality
    vim.notify("nvim-beads: create_issue not yet implemented", vim.log.levels.INFO)
end

return M
