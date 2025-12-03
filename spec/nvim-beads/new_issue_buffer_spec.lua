--- Unit tests for nvim-beads.buffer module - open_new_issue_buffer function
--- Tests the buffer creation and population for new issues

describe("nvim-beads.buffer", function()
    local buffer_module
    local env = require("test_utilities.env")

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.buffer"] = nil
        package.loaded["nvim-beads.issue.formatter"] = nil
        buffer_module = require("nvim-beads.buffer")
    end)

    describe("open_new_issue_buffer", function()
        before_each(function()
            env.setup_mock_env()
        end)

        after_each(function()
            env.teardown_mock_env()
        end)

        describe("argument validation", function()
            it("should return false and notify error when issue_type is nil", function()
                local template_data = { title = "", type = "task" }
                local success = buffer_module.open_new_issue_buffer(nil, template_data)

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue type", env.notifications[1].message)
                assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
            end)

            it("should return false and notify error when issue_type is invalid", function()
                local template_data = { title = "", type = "invalid" }
                local success = buffer_module.open_new_issue_buffer("invalid", template_data)

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue type", env.notifications[1].message)
            end)

            it("should return false and notify error when template_data is nil", function()
                local success = buffer_module.open_new_issue_buffer("task", nil)

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid template data", env.notifications[1].message)
                assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
            end)

            it("should return false and notify error when template_data is not a table", function()
                local success = buffer_module.open_new_issue_buffer("task", "not a table")

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid template data", env.notifications[1].message)
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
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.equals("beads://issue/new?type=task", env.buffer_name)
            end)

            it("should create buffer with correct name for bug", function()
                template_data.type = "bug"
                buffer_module.open_new_issue_buffer("bug", template_data)

                assert.equals("beads://issue/new?type=bug", env.buffer_name)
            end)

            it("should create buffer with correct name for feature", function()
                template_data.type = "feature"
                buffer_module.open_new_issue_buffer("feature", template_data)

                assert.equals("beads://issue/new?type=feature", env.buffer_name)
            end)

            it("should set filetype to markdown", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(env.created_bufnr)
                assert.equals("markdown", env.buffer_options[env.created_bufnr].filetype)
            end)

            it("should set buftype to acwrite", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.equals("acwrite", env.buffer_options[env.created_bufnr].buftype)
            end)

            it("should set bufhidden to hide", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.equals("hide", env.buffer_options[env.created_bufnr].bufhidden)
            end)

            it("should display buffer in current window", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.equals(env.created_bufnr, env.current_buf)
            end)

            it("should position cursor on title field", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(env.cursor_position)
                assert.equals(3, env.cursor_position[1]) -- Line 3 (title line)
                assert.equals(7, env.cursor_position[2]) -- Column 7 (after "title: ")
            end)

            it("should return true on success", function()
                local success = buffer_module.open_new_issue_buffer("task", template_data)

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
                buffer_module.open_new_issue_buffer("task", template_data)

                assert.is_not_nil(env.buffer_lines)
                local content = table.concat(env.buffer_lines, "\n")

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
                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
                assert.matches("priority: 1", content)
            end)

            it("should default to priority 2 if not in template", function()
                template_data.priority = nil
                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
                assert.matches("priority: 2", content)
            end)

            it("should include assignee if provided in template", function()
                template_data.assignee = "john.doe"
                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
                assert.matches("assignee: john%.doe", content)
            end)

            it("should include labels if provided in template", function()
                template_data.labels = { "ui", "backend" }
                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
                assert.matches("labels:", content)
                assert.matches("  %- ui", content)
                assert.matches("  %- backend", content)
            end)

            it("should have empty title ready for user input", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                -- Find the title line
                local title_line = nil
                for _, line in ipairs(env.buffer_lines) do
                    if line:match("^title:") then
                        title_line = line
                        break
                    end
                end

                assert.is_not_nil(title_line)
                assert.equals("title: ", title_line)
            end)

            it("should set status to open", function()
                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("feature", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("task", template_data)

                local content = table.concat(env.buffer_lines, "\n")
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

                buffer_module.open_new_issue_buffer("feature", template_data)

                assert.is_not_nil(env.buffer_lines)
                local content = table.concat(env.buffer_lines, "\n")

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
