--- Autocommand integration for nvim-beads
--- Handles save workflow for beads:// buffers

local M = {}

--- Setup autocommands for beads:// buffers
function M.setup()
    local group = vim.api.nvim_create_augroup("nvim_beads_buffers", { clear = true })

    -- Handle buffer write for beads:// buffers
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = group,
        pattern = "beads://issue/*",
        callback = M.on_buffer_write,
        desc = "Save beads issue buffer and sync with bd",
    })
end

--- Handle buffer write for beads:// issue buffers
---@param args table Autocommand callback arguments
function M.on_buffer_write(args)
    local bufnr = args.buf
    local buffer_name = vim.api.nvim_buf_get_name(bufnr)

    -- Check if this is a new issue buffer
    if buffer_name:match("beads://issue/new") then
        M.handle_new_issue_save(bufnr, buffer_name)
        return
    end

    -- Extract issue ID from buffer name (beads://issue/<id>)
    local issue_id = buffer_name:match("beads://issue/(.+)$")
    if not issue_id then
        vim.notify("nvim-beads: Invalid buffer name format", vim.log.levels.ERROR)
        return
    end

    M.handle_existing_issue_save(bufnr, issue_id)
end

--- Handle save workflow for new issue buffers
---@param bufnr number The buffer number
---@param buffer_name string The buffer name
function M.handle_new_issue_save(bufnr, buffer_name)
    -- Get buffer content
    local buffer_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Parse buffer content
    local issue_module = require("nvim-beads.issue")
    local ok, parsed_issue = pcall(issue_module.parse_markdown_to_issue, buffer_content)
    if not ok then
        vim.notify(string.format("nvim-beads: Failed to parse buffer: %s", parsed_issue), vim.log.levels.ERROR)
        return
    end

    -- Validate title is non-empty
    if not parsed_issue.title or parsed_issue.title == "" or parsed_issue.title == "(new)" then
        vim.notify("nvim-beads: Title is required to create issue", vim.log.levels.ERROR)
        return
    end

    -- Build create command
    local create_cmd, build_err = issue_module.build_create_command(parsed_issue)
    if build_err then
        vim.notify(string.format("nvim-beads: Failed to build create command: %s", build_err), vim.log.levels.ERROR)
        return
    end

    -- Add --json flag for programmatic output
    -- Discard stderr as bd emits additional messages there
    create_cmd = create_cmd .. " --json 2>/dev/null"

    -- Execute create command
    local output = vim.fn.system(create_cmd)
    local exit_code = vim.v.shell_error

    if exit_code ~= 0 then
        vim.notify(
            string.format("nvim-beads: Failed to create issue (exit %d): %s", exit_code, output),
            vim.log.levels.ERROR
        )
        return
    end

    -- Extract new issue ID from output
    local new_id, extract_err = issue_module.extract_id_from_create_output(output)
    if extract_err then
        vim.notify(string.format("nvim-beads: Failed to extract issue ID: %s", extract_err), vim.log.levels.ERROR)
        return
    end

    -- Rename buffer to use the new issue ID
    local new_buffer_name = string.format("beads://issue/%s", new_id)
    vim.api.nvim_buf_set_name(bufnr, new_buffer_name)

    -- Fetch the authoritative state from bd
    local core = require("nvim-beads.core")
    local result, err = core.execute_bd({ "show", new_id })
    if err then
        vim.notify(string.format("nvim-beads: Failed to fetch created issue %s: %s", new_id, err), vim.log.levels.ERROR)
        return
    end

    -- Extract issue from result array
    local created_issue = nil
    if type(result) == "table" and #result > 0 then
        created_issue = result[1]
    end

    if not created_issue or not created_issue.id then
        vim.notify(string.format("nvim-beads: Invalid issue data for %s", new_id), vim.log.levels.ERROR)
        return
    end

    -- Format the created issue
    local updated_lines = issue_module.format_issue_to_markdown(created_issue)

    -- Split any lines that contain newlines
    local final_lines = {}
    for _, line in ipairs(updated_lines) do
        if line:find("\n") then
            local pos = 1
            while pos <= #line do
                local next_newline = line:find("\n", pos, true)
                if next_newline then
                    table.insert(final_lines, line:sub(pos, next_newline - 1))
                    pos = next_newline + 1
                else
                    table.insert(final_lines, line:sub(pos))
                    break
                end
            end
        else
            table.insert(final_lines, line)
        end
    end

    -- Update buffer with authoritative content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

    -- Clear modified flag
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

    vim.notify(string.format("nvim-beads: Issue %s created successfully", new_id), vim.log.levels.INFO)
end

--- Handle save workflow for existing issue buffers
---@param bufnr number The buffer number
---@param issue_id string The issue ID
function M.handle_existing_issue_save(bufnr, issue_id)
    -- Save cursor position before reload
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Get buffer content
    local buffer_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Parse buffer content
    local issue_module = require("nvim-beads.issue")
    local ok, parsed_issue = pcall(issue_module.parse_markdown_to_issue, buffer_content)
    if not ok then
        vim.notify(string.format("nvim-beads: Failed to parse buffer: %s", parsed_issue), vim.log.levels.ERROR)
        return
    end

    -- Fetch original state from bd
    local core = require("nvim-beads.core")
    local result, err = core.execute_bd({ "show", issue_id })
    if err then
        vim.notify(string.format("nvim-beads: Failed to fetch issue %s: %s", issue_id, err), vim.log.levels.ERROR)
        return
    end

    -- Extract issue from result array
    local original_issue = nil
    if type(result) == "table" and #result > 0 then
        original_issue = result[1]
    end

    if not original_issue or not original_issue.id then
        vim.notify(string.format("nvim-beads: Invalid issue data for %s", issue_id), vim.log.levels.ERROR)
        return
    end

    -- Diff the states
    local changes = issue_module.diff_issues(original_issue, parsed_issue)

    -- Check if there are any changes
    if not next(changes) then
        vim.notify("nvim-beads: No changes detected", vim.log.levels.INFO)
        -- Clear modified flag
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        return
    end

    -- Handle parent removal if needed (we need the original parent ID)
    if changes.parent == "" then
        -- Find the original parent ID from dependencies
        local original_parent_id = nil
        if original_issue.dependencies then
            for _, dep in ipairs(original_issue.dependencies) do
                if dep.dependency_type == "parent-child" then
                    original_parent_id = dep.id
                    break
                end
            end
        end

        if original_parent_id then
            -- Execute parent removal first
            local remove_cmd = "bd dep remove " .. issue_id .. " " .. original_parent_id
            local remove_ok = pcall(vim.fn.system, remove_cmd)
            if not remove_ok then
                vim.notify(string.format("nvim-beads: Failed to remove parent: %s", remove_cmd), vim.log.levels.ERROR)
                return
            end
        end

        -- Clear the parent change from the changes table since we handled it
        changes.parent = nil
    end

    -- Generate update commands
    local commands = issue_module.generate_update_commands(issue_id, changes)

    if #commands == 0 then
        vim.notify("nvim-beads: No changes to apply", vim.log.levels.INFO)
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        return
    end

    -- Execute commands sequentially
    local all_success = true
    for i, cmd in ipairs(commands) do
        -- Execute command via shell
        local cmd_result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error

        if exit_code ~= 0 then
            vim.notify(
                string.format("nvim-beads: Command failed (exit %d): %s\nOutput: %s", exit_code, cmd, cmd_result),
                vim.log.levels.ERROR
            )
            all_success = false
            break
        end
    end

    -- If all commands succeeded, reload buffer from authoritative source
    if all_success then
        -- Fetch updated issue
        local updated_result, updated_err = core.execute_bd({ "show", issue_id })
        if updated_err then
            vim.notify(
                string.format("nvim-beads: Failed to reload issue %s: %s", issue_id, updated_err),
                vim.log.levels.ERROR
            )
            return
        end

        -- Extract updated issue
        local updated_issue = nil
        if type(updated_result) == "table" and #updated_result > 0 then
            updated_issue = updated_result[1]
        end

        if not updated_issue or not updated_issue.id then
            vim.notify(string.format("nvim-beads: Invalid updated issue data for %s", issue_id), vim.log.levels.ERROR)
            return
        end

        -- Format the updated issue
        local updated_lines = issue_module.format_issue_to_markdown(updated_issue)

        -- Split any lines that contain newlines, preserving blank lines
        local final_lines = {}
        for _, line in ipairs(updated_lines) do
            if line:find("\n") then
                -- Split on newlines, preserving blank lines
                local pos = 1
                while pos <= #line do
                    local next_newline = line:find("\n", pos, true)
                    if next_newline then
                        table.insert(final_lines, line:sub(pos, next_newline - 1))
                        pos = next_newline + 1
                    else
                        table.insert(final_lines, line:sub(pos))
                        break
                    end
                end
            else
                table.insert(final_lines, line)
            end
        end

        -- Update buffer with new content
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, final_lines)

        -- Clear modified flag
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

        -- Restore cursor position (clamped to valid range)
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local new_row = math.min(cursor_pos[1], line_count)
        local new_col = cursor_pos[2]

        -- Get the line at the new row and clamp column
        if new_row > 0 and new_row <= line_count then
            local line = vim.api.nvim_buf_get_lines(bufnr, new_row - 1, new_row, false)[1]
            if line then
                new_col = math.min(new_col, #line)
            end
        end

        vim.api.nvim_win_set_cursor(0, { new_row, new_col })

        vim.notify("nvim-beads: Issue saved successfully", vim.log.levels.INFO)
    end
end

return M
