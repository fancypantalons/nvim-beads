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
    if type(args) ~= "table" then
        return nil, "execute_bd: args must be a table"
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

    -- Build command
    local cmd = vim.list_extend({ "bd" }, args)

    -- Default options: text=true for clean output
    local system_opts = vim.tbl_extend("force", { text = true }, opts or {})

    -- Execute command synchronously
    local result = vim.system(cmd, system_opts):wait()

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

return M
