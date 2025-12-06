--- Core functionality for nvim-beads
--- Provides the main API for interacting with beads issue tracker

local M = {}

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
function M.show_ready()
    -- TODO: Implement show_ready functionality
    vim.notify("nvim-beads: show_ready not yet implemented", vim.log.levels.INFO)
end

--- Show list of all beads issues
---@param args table|nil Optional filter arguments [state, type]
function M.show_list(args)
    local filters, err = M.parse_list_filters(args)
    if err then
        vim.notify("Beads list: " .. err, vim.log.levels.ERROR)
        return
    end

    local has_telescope, telescope = pcall(require, "telescope")
    if not has_telescope then
        vim.notify(
            "nvim-beads: Telescope not found. Install telescope.nvim or use :Beads ready/list/create",
            vim.log.levels.WARN
        )
        return
    end

    -- Load the extension if not already loaded
    if not telescope.extensions.nvim_beads then
        telescope.load_extension("nvim_beads")
    end

    -- Call the default telescope picker
    telescope.extensions.nvim_beads.nvim_beads(filters)
end

--- Fetch template for a given issue type
---@param issue_type string The issue type (bug, feature, task, epic, chore)
---@return table|nil template Parsed template data on success, nil on failure
---@return string? error Error message on failure, nil on success
function M.fetch_template(issue_type)
    -- Validate issue type
    local valid_types = { bug = true, feature = true, task = true, epic = true, chore = true }
    if not valid_types[issue_type] then
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
            }, nil
        else
            -- For other errors (like JSON parsing), propagate the error
            return nil, err
        end
    end

    return result, nil
end

--- Parse list filter arguments from the command
---@param fargs table|nil The filter arguments from the command
---@return table? filters A table with parsed state and type, or nil on error
---@return string? err An error message if validation fails
function M.parse_list_filters(fargs)
    if not fargs or #fargs == 0 then
        return { state = "open", type = nil }, nil
    end

    local valid_states = {
        open = true,
        in_progress = true,
        blocked = true,
        closed = true,
        ready = true,
        stale = true,
        all = true,
    }
    local valid_types = {
        bug = true,
        feature = true,
        task = true,
        epic = true,
        chore = true,
        all = true,
    }
    local plural_map = {
        bugs = "bug",
        features = "feature",
        tasks = "task",
        epics = "epic",
        chores = "chore",
    }

    local filters = { state = nil, type = nil }

    for _, arg in ipairs(fargs) do
        local term = plural_map[string.lower(arg)] or string.lower(arg)

        local is_state = valid_states[term]
        local is_type = valid_types[term]

        if not is_state and not is_type then
            return nil, string.format("Invalid issue state or type '%s'", arg)
        end

        -- Prefer assigning to state if it's not taken yet
        if is_state and not filters.state then
            filters.state = term
        -- Then try assigning to type if it's not taken
        elseif is_type and not filters.type then
            filters.type = term
        else
            -- If we are here, it means both slots that the arg could fill are taken.
            if is_state and is_type then
                return nil, string.format("Duplicate or ambiguous state and type for '%s'", arg)
            elseif is_state then
                return nil, string.format("Duplicate issue state '%s'", arg)
            else -- is_type
                return nil, string.format("Duplicate issue type '%s'", arg)
            end
        end
    end

    return filters, nil
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

--- Fetches and parses a single issue by its ID asynchronously.
---@param issue_id string The ID of the issue to fetch.
---@param callback function Callback function(issue: table|nil, err: string|nil)
function M.get_issue_async(issue_id, callback)
    -- Validate issue_id
    if not issue_id or type(issue_id) ~= "string" or issue_id == "" then
        vim.schedule(function()
            callback(nil, "Invalid issue ID")
        end)
        return
    end

    -- Execute bd show command
    M.execute_bd_async({ "show", issue_id }, function(result, err)
        if err then
            callback(nil, string.format("Failed to fetch issue %s: %s", issue_id, err))
            return
        end

        -- bd show returns an array with a single issue object
        local issue = nil
        if type(result) == "table" and #result > 0 then
            issue = result[1]
        end

        if not issue or not issue.id then
            callback(nil, string.format("Invalid issue data for %s", issue_id))
            return
        end

        callback(issue, nil)
    end)
end

return M
