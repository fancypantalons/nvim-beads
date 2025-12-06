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
        M.handle_new_issue_save(bufnr)
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
function M.handle_new_issue_save(bufnr)
    -- Get buffer content
    local buffer_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Parse buffer content
    local parser = require("nvim-beads.issue.parser")
    local diff = require("nvim-beads.issue.diff")
    local ok, parsed_issue = pcall(parser.parse_markdown_to_issue, buffer_content)
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
    local create_cmd, build_err = diff.build_create_command(parsed_issue)
    if build_err then
        vim.notify(string.format("nvim-beads: Failed to build create command: %s", build_err), vim.log.levels.ERROR)
        return
    end

    -- Execute create command using vim.system
    local result = vim.system(create_cmd, { text = true }):wait()

    if result.code ~= 0 then
        local stderr = result.stderr or "no error output"
        vim.notify(
            string.format("nvim-beads: Failed to create issue (exit %d): %s", result.code, stderr),
            vim.log.levels.ERROR
        )
        return
    end

    -- Extract new issue ID from output
    local new_id, extract_err = diff.extract_id_from_create_output(result.stdout)
    if extract_err then
        vim.notify(string.format("nvim-beads: Failed to extract issue ID: %s", extract_err), vim.log.levels.ERROR)
        return
    end

    -- Rename buffer to use the new issue ID
    local new_buffer_name = string.format("beads://issue/%s", new_id)
    vim.api.nvim_buf_set_name(bufnr, new_buffer_name)

    -- Reload buffer with authoritative content from the newly created issue
    local buffer = require("nvim-beads.buffer")
    if buffer.reload_buffer_from_issue_id(bufnr, new_id) then
        vim.notify(string.format("nvim-beads: Issue %s created successfully", new_id), vim.log.levels.INFO)
    end
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
    local parser = require("nvim-beads.issue.parser")
    local diff = require("nvim-beads.issue.diff")
    local ok, parsed_issue = pcall(parser.parse_markdown_to_issue, buffer_content)
    if not ok then
        vim.notify(string.format("nvim-beads: Failed to parse buffer: %s", parsed_issue), vim.log.levels.ERROR)
        return
    end

    -- Fetch original state from bd
    local core = require("nvim-beads.core")
    local original_issue, err = core.get_issue(issue_id)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return
    end

    -- Diff the states
    local changes = diff.diff_issues(original_issue, parsed_issue)

    -- Check if there are any changes
    if not next(changes) then
        vim.notify("nvim-beads: No changes detected", vim.log.levels.INFO)
        -- Clear modified flag
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        return
    end

    -- Find the original parent ID, if any, for the command generator
    local original_parent_id = nil
    if changes.parent == "" and original_issue.dependencies then
        for _, dep in ipairs(original_issue.dependencies) do
            if dep.dependency_type == "parent-child" then
                original_parent_id = dep.id
                break
            end
        end
    end

    -- Generate update commands
    local commands = diff.generate_update_commands(issue_id, changes, original_parent_id)

    if #commands == 0 then
        vim.notify("nvim-beads: No changes to apply", vim.log.levels.INFO)
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        return
    end

    -- Execute commands sequentially
    local all_success = true
    for _, cmd_table in ipairs(commands) do
        -- Execute command via vim.system
        local result = vim.system(cmd_table, { text = true }):wait()

        if result.code ~= 0 then
            local stderr = result.stderr or "no error output"
            local cmd_str = table.concat(cmd_table, " ")
            vim.notify(
                string.format("nvim-beads: Command failed (exit %d): %s\nError: %s", result.code, cmd_str, stderr),
                vim.log.levels.ERROR
            )
            all_success = false
            break
        end
    end

    -- If all commands succeeded, reload buffer from authoritative source
    if all_success then
        local buffer = require("nvim-beads.buffer")
        if buffer.reload_buffer_from_issue_id(bufnr, issue_id) then
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
end

return M
