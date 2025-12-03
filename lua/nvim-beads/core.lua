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
    args = args or {}
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
    telescope.extensions.nvim_beads.nvim_beads()
    return
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

return M
