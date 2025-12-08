--- Unit tests for nvim-beads.issue.formatter module
--- Tests the format_issue_to_markdown function

describe("nvim-beads.issue.formatter", function()
    local formatter

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.issue.formatter"] = nil
        formatter = require("nvim-beads.issue.formatter")
    end)

    describe("format_issue_to_markdown", function()
        it("should format minimal issue with only required fields", function()
            local issue = {
                id = "bd-1",
                title = "Test Issue",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                closed_at = nil,
            }

            local lines = formatter.format_issue_to_markdown(issue)

            assert.is_table(lines)
            assert.equals("---", lines[1])
            assert.equals("id: bd-1", lines[2])
            assert.equals("title: Test Issue", lines[3])
            assert.equals("type: task", lines[4])
            assert.equals("status: open", lines[5])
            assert.equals("priority: 2", lines[6])
            assert.equals("created_at: 2023-10-27T10:00:00Z", lines[7])
            assert.equals("updated_at: 2023-10-27T12:00:00Z", lines[8])
            assert.equals("closed_at: null", lines[9])
            assert.equals("---", lines[10])
            assert.equals("", lines[11])
            -- Main sections should be shown (even though empty)
            assert.equals("# Description", lines[12])
            assert.equals("", lines[13])
            assert.equals("# Acceptance Criteria", lines[14])
            assert.equals("", lines[15])
            assert.equals("# Design", lines[16])
            assert.equals("", lines[17])
        end)

        it("should map issue_type to type in frontmatter", function()
            local issue = {
                id = "bd-1",
                title = "Bug Fix",
                issue_type = "bug",
                status = "open",
                priority = 1,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
            }

            local lines = formatter.format_issue_to_markdown(issue)

            -- Find the type line
            local found_type = false
            for _, line in ipairs(lines) do
                if line:match("^type:") then
                    assert.equals("type: bug", line)
                    found_type = true
                    break
                end
            end
            assert.is_true(found_type, "Should have type field in frontmatter")
        end)

        it("should include parent field when parent-child dependency exists", function()
            local issue = {
                id = "bd-5",
                title = "Child Issue",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                dependencies = {
                    {
                        id = "bd-100",
                        title = "Parent Issue",
                        dependency_type = "parent-child",
                    },
                },
            }

            local lines = formatter.format_issue_to_markdown(issue)

            -- Find the parent line
            local found_parent = false
            for _, line in ipairs(lines) do
                if line:match("^parent:") then
                    assert.equals("parent: bd-100", line)
                    found_parent = true
                    break
                end
            end
            assert.is_true(found_parent, "Should have parent field when parent-child dependency exists")
        end)

        it("should include dependencies list for blocks type", function()
            local issue = {
                id = "bd-7",
                title = "Issue with dependencies",
                issue_type = "feature",
                status = "blocked",
                priority = 1,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                dependencies = {
                    {
                        id = "bd-120",
                        title = "First Blocker",
                        dependency_type = "blocks",
                    },
                    {
                        id = "bd-121",
                        title = "Second Blocker",
                        dependency_type = "blocks",
                    },
                },
            }

            local lines = formatter.format_issue_to_markdown(issue)

            -- Convert to string for easier searching
            local content = table.concat(lines, "\n")

            assert.matches("dependencies:", content)
            assert.matches("  %- bd%-120", content)
            assert.matches("  %- bd%-121", content)
        end)

        it("should exclude parent-child from dependencies list", function()
            local issue = {
                id = "bd-8",
                title = "Issue with mixed dependencies",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                dependencies = {
                    {
                        id = "bd-100",
                        title = "Parent",
                        dependency_type = "parent-child",
                    },
                    {
                        id = "bd-121",
                        title = "Blocker",
                        dependency_type = "blocks",
                    },
                },
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            -- Should have parent field
            assert.matches("parent: bd%-100", content)

            -- Should have dependencies with only the blocker
            assert.matches("dependencies:", content)
            assert.matches("  %- bd%-121", content)

            -- Parent should not appear in dependencies list
            local deps_section = content:match("dependencies:(.-)created_at:")
            assert.is_not_nil(deps_section)
            assert.is_nil(deps_section:match("bd%-100"))
        end)

        it("should include labels when present", function()
            local issue = {
                id = "bd-9",
                title = "Labeled Issue",
                issue_type = "feature",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                labels = { "ui", "backend", "urgent" },
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("labels:", content)
            assert.matches("  %- ui", content)
            assert.matches("  %- backend", content)
            assert.matches("  %- urgent", content)
        end)

        it("should omit labels when empty array", function()
            local issue = {
                id = "bd-10",
                title = "No Labels",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                labels = {},
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.is_nil(content:match("labels:"))
        end)

        it("should include assignee when present", function()
            local issue = {
                id = "bd-11",
                title = "Assigned Issue",
                issue_type = "bug",
                status = "in_progress",
                priority = 1,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                assignee = "john.doe",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("assignee: john%.doe", content)
        end)

        it("should include description section when present", function()
            local issue = {
                id = "bd-12",
                title = "Issue with Description",
                issue_type = "feature",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                description = "This is a detailed description of the issue.",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("# Description", content)
            assert.matches("This is a detailed description of the issue%.", content)
        end)

        it("should use single # for section headings", function()
            local issue = {
                id = "bd-13",
                title = "Check Heading Levels",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                description = "Test description",
                acceptance_criteria = "Test criteria",
                design = "Test design",
                notes = "Test notes",
            }

            local lines = formatter.format_issue_to_markdown(issue)

            -- Find all heading lines
            local headings = {}
            for _, line in ipairs(lines) do
                if line:match("^#%s") then
                    table.insert(headings, line)
                end
            end

            -- Should have exactly 4 headings
            assert.equals(4, #headings)

            -- All should use single #
            for _, heading in ipairs(headings) do
                assert.is_not_nil(heading:match("^# %w"))
                assert.is_nil(heading:match("^## "))
            end
        end)

        it("should include acceptance_criteria section when present", function()
            local issue = {
                id = "bd-14",
                title = "Issue with Acceptance Criteria",
                issue_type = "feature",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                acceptance_criteria = "Must pass all tests\nMust work on all browsers",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("# Acceptance Criteria", content)
            assert.matches("Must pass all tests", content)
        end)

        it("should include design section when present", function()
            local issue = {
                id = "bd-15",
                title = "Issue with Design",
                issue_type = "feature",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                design = "Use MVC pattern\nImplement with React",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("# Design", content)
            assert.matches("Use MVC pattern", content)
        end)

        it("should include notes section when present", function()
            local issue = {
                id = "bd-16",
                title = "Issue with Notes",
                issue_type = "bug",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                notes = "Remember to update documentation",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("# Notes", content)
            assert.matches("Remember to update documentation", content)
        end)

        it("should show description header even when empty", function()
            local issue = {
                id = "bd-17",
                title = "Issue without Description",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                description = "",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            -- Description header should be shown even when empty
            assert.is_not_nil(content:match("# Description"))
        end)

        it("should show main section headers even when sections are nil or empty", function()
            local issue = {
                id = "bd-18",
                title = "Issue with nil sections",
                issue_type = "task",
                status = "open",
                priority = 2,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                description = nil,
                acceptance_criteria = nil,
                design = nil,
                notes = nil,
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            -- Main sections (Description, Acceptance Criteria, Design) should always show headers
            assert.is_not_nil(content:match("# Description"))
            assert.is_not_nil(content:match("# Acceptance Criteria"))
            assert.is_not_nil(content:match("# Design"))
            -- Notes section should only show when it has content
            assert.is_nil(content:match("# Notes"))
        end)

        it("should show closed_at timestamp when present", function()
            local issue = {
                id = "bd-19",
                title = "Closed Issue",
                issue_type = "bug",
                status = "closed",
                priority = 1,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                closed_at = "2023-10-27T14:00:00Z",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            assert.matches("closed_at: 2023%-10%-27T14:00:00Z", content)
        end)

        it("should format complete issue with all fields", function()
            local issue = {
                id = "bd-20",
                title = "Complete Issue",
                issue_type = "feature",
                status = "in_progress",
                priority = 1,
                created_at = "2023-10-27T10:00:00Z",
                updated_at = "2023-10-27T12:00:00Z",
                closed_at = nil,
                assignee = "jane.smith",
                labels = { "ui", "backend" },
                dependencies = {
                    {
                        id = "bd-100",
                        title = "Parent",
                        dependency_type = "parent-child",
                    },
                    {
                        id = "bd-120",
                        title = "Blocker 1",
                        dependency_type = "blocks",
                    },
                    {
                        id = "bd-121",
                        title = "Blocker 2",
                        dependency_type = "blocks",
                    },
                },
                description = "A comprehensive description",
                acceptance_criteria = "Must meet all requirements",
                design = "Technical design notes",
                notes = "Additional information",
            }

            local lines = formatter.format_issue_to_markdown(issue)
            local content = table.concat(lines, "\n")

            -- Check frontmatter fields
            assert.matches("id: bd%-20", content)
            assert.matches("title: Complete Issue", content)
            assert.matches("type: feature", content)
            assert.matches("status: in_progress", content)
            assert.matches("priority: 1", content)
            assert.matches("parent: bd%-100", content)
            assert.matches("dependencies:", content)
            assert.matches("  %- bd%-120", content)
            assert.matches("  %- bd%-121", content)
            assert.matches("labels:", content)
            assert.matches("  %- ui", content)
            assert.matches("  %- backend", content)
            assert.matches("assignee: jane%.smith", content)

            -- Check markdown sections
            assert.matches("# Description", content)
            assert.matches("A comprehensive description", content)
            assert.matches("# Acceptance Criteria", content)
            assert.matches("Must meet all requirements", content)
            assert.matches("# Design", content)
            assert.matches("Technical design notes", content)
            assert.matches("# Notes", content)
            assert.matches("Additional information", content)
        end)
    end)

    describe("open_issue_buffer", function()
        local buffer_module
        local env = require("test_utilities.env")

        before_each(function()
            -- Clear the module cache
            package.loaded["nvim-beads.buffer"] = nil
            package.loaded["nvim-beads.issue.formatter"] = nil
            package.loaded["nvim-beads.core"] = nil
            buffer_module = require("nvim-beads.buffer")

            env.setup_mock_env()
        end)

        after_each(function()
            env.teardown_mock_env()
        end)

        describe("argument validation", function()
            it("should return false and notify error when issue_id is nil", function()
                local success = buffer_module.open_issue_buffer(nil)

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue ID", env.notifications[1].message)
                assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
            end)

            it("should return false and notify error when issue_id is empty string", function()
                local success = buffer_module.open_issue_buffer("")

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue ID", env.notifications[1].message)
            end)

            it("should return false and notify error when issue_id is not a string", function()
                local success = buffer_module.open_issue_buffer(123)

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue ID", env.notifications[1].message)
            end)
        end)

        describe("bd command execution", function()
            it("should execute bd show with the correct issue_id", function()
                local executed_args = nil

                -- Mock core.execute_bd
                local core = require("nvim-beads.core")
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(args)
                    executed_args = args
                    return {
                        {
                            id = "bd-1",
                            title = "Test",
                            issue_type = "task",
                            status = "open",
                            priority = 2,
                            created_at = "2023-10-27T10:00:00Z",
                            updated_at = "2023-10-27T12:00:00Z",
                        },
                    },
                        nil
                end

                buffer_module.open_issue_buffer("bd-1")

                assert.is_not_nil(executed_args)
                assert.equals("show", executed_args[1])
                assert.equals("bd-1", executed_args[2])

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it("should return false and notify error when bd command fails", function()
                local core = require("nvim-beads.core")
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(_)
                    return nil, "Command failed: bd not found"
                end

                local success = buffer_module.open_issue_buffer("bd-1")

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Failed to fetch issue bd%-1", env.notifications[1].message)
                assert.matches("Command failed", env.notifications[1].message)
                assert.equals(vim.log.levels.ERROR, env.notifications[1].level)

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it("should return false when issue data is invalid", function()
                local core = require("nvim-beads.core")
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(_)
                    return {}, nil -- Empty array
                end

                local success = buffer_module.open_issue_buffer("bd-1")

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue data", env.notifications[1].message)

                -- Restore
                core.execute_bd = original_execute_bd
            end)

            it("should return false when result array contains invalid issue", function()
                local core = require("nvim-beads.core")
                local original_execute_bd = core.execute_bd
                core.execute_bd = function(_)
                    return { {} }, nil -- Array with empty object
                end

                local success = buffer_module.open_issue_buffer("bd-1")

                assert.is_false(success)
                assert.equals(1, #env.notifications)
                assert.matches("Invalid issue data", env.notifications[1].message)

                -- Restore
                core.execute_bd = original_execute_bd
            end)
        end)

        describe("buffer creation and configuration", function()
            before_each(function()
                -- Mock successful bd execution
                local core = require("nvim-beads.core")
                core.execute_bd = function(_)
                    return {
                        {
                            id = "bd-1",
                            title = "Test Issue",
                            issue_type = "task",
                            status = "open",
                            priority = 2,
                            created_at = "2023-10-27T10:00:00Z",
                            updated_at = "2023-10-27T12:00:00Z",
                        },
                    },
                        nil
                end
            end)

            it("should create buffer with correct name", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.equals("beads://issue/bd-1", env.buffer_name)
            end)

            it("should create buffer with correct name for longer issue IDs", function()
                -- Mock bd execution for longer ID
                local core = require("nvim-beads.core")
                core.execute_bd = function(_)
                    return {
                        {
                            id = "nvim-beads-p69",
                            title = "Test",
                            issue_type = "task",
                            status = "open",
                            priority = 2,
                            created_at = "2023-10-27T10:00:00Z",
                            updated_at = "2023-10-27T12:00:00Z",
                        },
                    },
                        nil
                end

                buffer_module.open_issue_buffer("nvim-beads-p69")

                assert.equals("beads://issue/nvim-beads-p69", env.buffer_name)
            end)

            it("should set filetype to markdown", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.is_not_nil(env.buffer_options[env.created_bufnr])
                assert.equals("markdown", env.buffer_options[env.created_bufnr].filetype)
            end)

            it("should set buftype to acwrite", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.equals("acwrite", env.buffer_options[env.created_bufnr].buftype)
            end)

            it("should set bufhidden to hide", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.equals("hide", env.buffer_options[env.created_bufnr].bufhidden)
            end)

            it("should populate buffer with formatted content", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.is_not_nil(env.buffer_lines)
                assert.is_table(env.buffer_lines)
                assert.is_true(#env.buffer_lines > 0)

                -- Check for YAML frontmatter
                local content = table.concat(env.buffer_lines, "\n")
                assert.matches("---", content)
                assert.matches("id: bd%-1", content)
                assert.matches("title: Test Issue", content)
            end)

            it("should display buffer in current window", function()
                buffer_module.open_issue_buffer("bd-1")

                assert.equals(env.created_bufnr, env.current_buf)
            end)

            it("should return true on success", function()
                local success = buffer_module.open_issue_buffer("bd-1")

                assert.is_true(success)
            end)
        end)

        describe("integration with format_issue_to_markdown", function()
            it("should format complete issue correctly in buffer", function()
                local core = require("nvim-beads.core")
                core.execute_bd = function(_)
                    return {
                        {
                            id = "bd-20",
                            title = "Complete Issue",
                            issue_type = "feature",
                            status = "in_progress",
                            priority = 1,
                            created_at = "2023-10-27T10:00:00Z",
                            updated_at = "2023-10-27T12:00:00Z",
                            closed_at = nil,
                            assignee = "jane.smith",
                            labels = { "ui", "backend" },
                            dependencies = {
                                {
                                    id = "bd-100",
                                    title = "Parent",
                                    dependency_type = "parent-child",
                                },
                                {
                                    id = "bd-120",
                                    title = "Blocker",
                                    dependency_type = "blocks",
                                },
                            },
                            description = "A comprehensive description",
                            acceptance_criteria = "Must meet all requirements",
                            design = "Technical design notes",
                            notes = "Additional information",
                        },
                    },
                        nil
                end

                buffer_module.open_issue_buffer("bd-20")

                assert.is_not_nil(env.buffer_lines)
                local content = table.concat(env.buffer_lines, "\n")

                -- Verify all sections are included
                assert.matches("id: bd%-20", content)
                assert.matches("title: Complete Issue", content)
                assert.matches("assignee: jane%.smith", content)
                assert.matches("parent: bd%-100", content)
                assert.matches("  %- bd%-120", content)
                assert.matches("# Description", content)
                assert.matches("# Acceptance Criteria", content)
                assert.matches("# Design", content)
                assert.matches("# Notes", content)
            end)
        end)
    end)
end)
