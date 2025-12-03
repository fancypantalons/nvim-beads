--- Unit tests for nvim-beads.issue module - open_new_issue_buffer function
--- Tests the buffer creation and population for new issues

describe("nvim-beads.issue", function()
    local issue_module

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue"] = nil
        issue_module = require("nvim-beads.issue")
    end)

    describe("open_new_issue_buffer", function()
        local original_vim_api_create_buf
        local original_vim_api_set_name
        local original_vim_api_set_lines
        local original_vim_api_set_option_value
        local original_vim_api_set_current_buf
        local original_vim_api_win_set_cursor
        local original_vim_notify

        -- Mock state
        local created_bufnr
        local buffer_name
        local buffer_lines
        local buffer_options
        local current_buf
        local cursor_position
        local notifications

        before_each(function()
            -- Save originals
            original_vim_api_create_buf = vim.api.nvim_create_buf
            original_vim_api_set_name = vim.api.nvim_buf_set_name
            original_vim_api_set_lines = vim.api.nvim_buf_set_lines
            original_vim_api_set_option_value = vim.api.nvim_set_option_value
            original_vim_api_set_current_buf = vim.api.nvim_set_current_buf
            original_vim_api_win_set_cursor = vim.api.nvim_win_set_cursor
            original_vim_notify = vim.notify

            -- Reset mock state
            created_bufnr = 42
            buffer_name = nil
            buffer_lines = nil
            buffer_options = {}
            current_buf = nil
            cursor_position = nil
            notifications = {}

            -- Mock vim.api functions
            vim.api.nvim_create_buf = function(_, _)
                return created_bufnr
            end

            vim.api.nvim_buf_set_name = function(_, name)
                buffer_name = name
            end

            vim.api.nvim_buf_set_lines = function(_, _, _, _, lines)
                buffer_lines = lines
            end

            vim.api.nvim_set_option_value = function(option, value, opts)
                if opts and opts.buf then
                    if not buffer_options[opts.buf] then
                        buffer_options[opts.buf] = {}
                    end
                    buffer_options[opts.buf][option] = value
                end
            end

            vim.api.nvim_set_current_buf = function(bufnr)
                current_buf = bufnr
            end

            vim.api.nvim_win_set_cursor = function(_, pos)
                cursor_position = pos
            end

            vim.notify = function(msg, level)
                table.insert(notifications, { message = msg, level = level })
            end
        end)

        after_each(function()
            -- Restore originals
            vim.api.nvim_create_buf = original_vim_api_create_buf
            vim.api.nvim_buf_set_name = original_vim_api_set_name
            vim.api.nvim_buf_set_lines = original_vim_api_set_lines
            vim.api.nvim_set_option_value = original_vim_api_set_option_value
            vim.api.nvim_set_current_buf = original_vim_api_set_current_buf
            vim.api.nvim_win_set_cursor = original_vim_api_win_set_cursor
            vim.notify = original_vim_notify
        end)

        describe("argument validation", function()
            it("should return false and notify error when issue_type is nil", function()
                local template_data = { title = "", type = "task" }
                local success = issue_module.open_new_issue_buffer(nil, template_data)

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches("Invalid issue type", notifications[1].message)
                assert.equals(vim.log.levels.ERROR, notifications[1].level)
            end)

            it("should return false and notify error when issue_type is invalid", function()
                local template_data = { title = "", type = "invalid" }
                local success = issue_module.open_new_issue_buffer("invalid", template_data)

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches("Invalid issue type", notifications[1].message)
            end)

            it("should return false and notify error when template_data is nil", function()
                local success = issue_module.open_new_issue_buffer("task", nil)

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches("Invalid template data", notifications[1].message)
                assert.equals(vim.log.levels.ERROR, notifications[1].level)
            end)

            it("should return false and notify error when template_data is not a table", function()
                local success = issue_module.open_new_issue_buffer("task", "not a table")

                assert.is_false(success)
                assert.equals(1, #notifications)
                assert.matches("Invalid template data", notifications[1].message)
            end)
        end)

        describe("buffer creation and configuration", function()
            local template_data

            before_each(function()
                template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                }
            end)

            it("should create buffer with correct name for task", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.equals("beads://issue/new?type=task", buffer_name)
            end)

            it("should create buffer with correct name for bug", function()
                template_data.type = "bug"
                issue_module.open_new_issue_buffer("bug", template_data)

                assert.equals("beads://issue/new?type=bug", buffer_name)
            end)

            it("should create buffer with correct name for feature", function()
                template_data.type = "feature"
                issue_module.open_new_issue_buffer("feature", template_data)

                assert.equals("beads://issue/new?type=feature", buffer_name)
            end)

            it("should set filetype to markdown", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(buffer_options[created_bufnr])
                assert.equals("markdown", buffer_options[created_bufnr].filetype)
            end)

            it("should set buftype to acwrite", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.equals("acwrite", buffer_options[created_bufnr].buftype)
            end)

            it("should set bufhidden to hide", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.equals("hide", buffer_options[created_bufnr].bufhidden)
            end)

            it("should display buffer in current window", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.equals(created_bufnr, current_buf)
            end)

            it("should position cursor on title field", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(cursor_position)
                assert.equals(3, cursor_position[1]) -- Line 3 (title line)
                assert.equals(7, cursor_position[2]) -- Column 7 (after "title: ")
            end)

            it("should return true on success", function()
                local success = issue_module.open_new_issue_buffer("task", template_data)

                assert.is_true(success)
            end)
        end)

        describe("YAML frontmatter content", function()
            local template_data

            before_each(function()
                template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                }
            end)

            it("should contain correct fields with template defaults", function()
                issue_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(buffer_lines)
                local content = table.concat(buffer_lines, "\n")

                assert.matches("---", content)
                assert.matches("id: %(new%)", content)
                assert.matches("title: \n", content) -- Empty title with newline
                assert.matches("type: task", content)
                assert.matches("status: open", content)
                assert.matches("priority: 2", content)
                assert.matches("created_at: null", content)
                assert.matches("updated_at: null", content)
                assert.matches("closed_at: null", content)
            end)

            it("should use priority from template if provided", function()
                template_data.priority = 1
                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("priority: 1", content)
            end)

            it("should default to priority 2 if not in template", function()
                template_data.priority = nil
                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("priority: 2", content)
            end)

            it("should include assignee if provided in template", function()
                template_data.assignee = "john.doe"
                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("assignee: john%.doe", content)
            end)

            it("should include labels if provided in template", function()
                template_data.labels = { "ui", "backend" }
                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("labels:", content)
                assert.matches("  %- ui", content)
                assert.matches("  %- backend", content)
            end)

            it("should have empty title ready for user input", function()
                issue_module.open_new_issue_buffer("task", template_data)

                -- Find the title line
                local title_line = nil
                for _, line in ipairs(buffer_lines) do
                    if line:match("^title:") then
                        title_line = line
                        break
                    end
                end

                assert.is_not_nil(title_line)
                assert.equals("title: ", title_line)
            end)

            it("should set status to open", function()
                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("status: open", content)
            end)
        end)

        describe("Markdown sections from template", function()
            it("should populate description section from template", function()
                local template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                    description = "Template description text",
                }

                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("# Description", content)
                assert.matches("Template description text", content)
            end)

            it("should populate acceptance_criteria section from template", function()
                local template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                    acceptance_criteria = "- [ ] Criterion 1\n- [ ] Criterion 2",
                }

                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("# Acceptance Criteria", content)
                assert.matches("Criterion 1", content)
                assert.matches("Criterion 2", content)
            end)

            it("should populate design section from template", function()
                local template_data = {
                    title = "",
                    type = "feature",
                    priority = 2,
                    design = "Design approach here",
                }

                issue_module.open_new_issue_buffer("feature", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("# Design", content)
                assert.matches("Design approach here", content)
            end)

            it("should populate notes section from template", function()
                local template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                    notes = "Important notes",
                }

                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                assert.matches("# Notes", content)
                assert.matches("Important notes", content)
            end)

            it("should handle empty template sections gracefully", function()
                local template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                    description = "",
                    acceptance_criteria = "",
                    design = "",
                    notes = "",
                }

                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                -- Main sections (Description, Acceptance Criteria, Design) should always show headers
                assert.is_not_nil(content:match("# Description"))
                assert.is_not_nil(content:match("# Acceptance Criteria"))
                assert.is_not_nil(content:match("# Design"))
                -- Notes should not appear when empty
                assert.is_nil(content:match("# Notes"))
            end)

            it("should handle missing template sections gracefully", function()
                local template_data = {
                    title = "",
                    type = "task",
                    priority = 2,
                    -- No description, acceptance_criteria, design, or notes
                }

                issue_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(buffer_lines, "\n")
                -- Main sections (Description, Acceptance Criteria, Design) should always show headers
                assert.is_not_nil(content:match("# Description"))
                assert.is_not_nil(content:match("# Acceptance Criteria"))
                assert.is_not_nil(content:match("# Design"))
                -- Notes should not appear when missing
                assert.is_nil(content:match("# Notes"))
            end)
        end)

        describe("complete template with all fields", function()
            it("should format complete template correctly in buffer", function()
                local template_data = {
                    title = "",
                    type = "feature",
                    priority = 1,
                    assignee = "jane.smith",
                    labels = { "ui", "backend" },
                    description = "Feature description",
                    acceptance_criteria = "- [ ] Must work\n- [ ] Must be tested",
                    design = "Technical design approach",
                    notes = "Additional notes here",
                }

                issue_module.open_new_issue_buffer("feature", template_data)

                assert.is_not_nil(buffer_lines)
                local content = table.concat(buffer_lines, "\n")

                -- Verify YAML frontmatter
                assert.matches("id: %(new%)", content)
                assert.matches("title: \n", content) -- Empty title with newline
                assert.matches("type: feature", content)
                assert.matches("status: open", content)
                assert.matches("priority: 1", content)
                assert.matches("assignee: jane%.smith", content)
                assert.matches("labels:", content)
                assert.matches("  %- ui", content)
                assert.matches("  %- backend", content)

                -- Verify Markdown sections
                assert.matches("# Description", content)
                assert.matches("Feature description", content)
                assert.matches("# Acceptance Criteria", content)
                assert.matches("Must work", content)
                assert.matches("# Design", content)
                assert.matches("Technical design approach", content)
                assert.matches("# Notes", content)
                assert.matches("Additional notes here", content)
            end)
        end)
    end)
end)
