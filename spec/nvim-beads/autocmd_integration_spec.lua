--- Integration tests for autocmd save workflow
--- Tests the full new issue creation and existing issue update workflows

describe("autocmd save workflow", function()
    local autocmds
    local core_module
    local original_vim_v
    local env = require("test_utilities.env")
    local test_bufnr
    local mock_shell_error

    before_each(function()
        -- Clear module cache
        package.loaded["nvim-beads.autocmds"] = nil
        package.loaded["nvim-beads.issue"] = nil
        package.loaded["nvim-beads.core"] = nil

        autocmds = require("nvim-beads.autocmds")
        core_module = require("nvim-beads.core")

        env.setup_mock_env()

        -- Create a test buffer
        test_bufnr = vim.api.nvim_create_buf(false, false)

        -- Save original functions that are not mocked by env
        original_vim_v = vim.v

        -- Mock vim.v with writable shell_error
        -- mock_shell_error no longer used
        vim.v = setmetatable({}, {
            __index = function(_, k)
                if k == "shell_error" then
                    return mock_shell_error
                end
                return original_vim_v[k]
            end,
            __newindex = function(t, k, v)
                if k == "shell_error" then
                    mock_shell_error = v
                else
                    rawset(t, k, v)
                end
            end,
        })
    end)

    after_each(function()
        -- Restore original functions
        env.teardown_mock_env()
        vim.v = original_vim_v

        -- Delete test buffer if it exists
        if vim.api.nvim_buf_is_valid(test_bufnr) then
            vim.api.nvim_buf_delete(test_bufnr, { force = true })
        end
    end)

    describe("new issue creation workflow", function()
        it("should create minimal issue with title only", function()
            -- Set up buffer content (minimal new issue)
            local buffer_content = {
                "---",
                "id: (new)",
                "title: Fix parsing bug",
                "type: bug",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "Parser fails on edge cases",
                "",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=bug")

            -- Mock vim.system for create command
            local create_output = '{"id":"bd-42","title":"Fix parsing bug","issue_type":"bug"}'
            local system_calls = {}

            vim.system = function(cmd_table, _opts)
                table.insert(system_calls, cmd_table)
                local result = {
                    code = 0,
                    stdout = "",
                    stderr = "",
                }
                if cmd_table[1] == "bd" and cmd_table[2] == "create" then
                    result.stdout = create_output
                end
                return {
                    wait = function()
                        return result
                    end,
                }
            end

            -- Mock core.execute_bd for show command
            core_module.execute_bd = function(args)
                if args[1] == "show" and args[2] == "bd-42" then
                    return {
                        {
                            id = "bd-42",
                            title = "Fix parsing bug",
                            issue_type = "bug",
                            status = "open",
                            priority = 2,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Parser fails on edge cases",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=bug")

            -- Verify create command was called
            assert.equals(1, #system_calls)
            assert.equals("bd", system_calls[1][1])
            assert.equals("create", system_calls[1][2])
            assert.is_true(vim.tbl_contains(system_calls[1], "--json"))

            -- Verify buffer was renamed
            local new_name = vim.api.nvim_buf_get_name(test_bufnr)
            assert.equals("beads://issue/bd-42", new_name)

            -- Verify success notification
            local found_success = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("bd%-42 created successfully") then
                    found_success = true
                    break
                end
            end
            assert.is_true(found_success)
        end)

        it("should create issue with all fields populated", function()
            local buffer_content = {
                "---",
                "id: (new)",
                "title: Add dark mode",
                "type: feature",
                "status: open",
                "priority: 1",
                "parent: bd-100",
                "dependencies:",
                "  - bd-50",
                "  - bd-60",
                "labels:",
                "  - ui",
                "  - frontend",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "Add dark mode toggle to settings",
                "",
                "# Acceptance Criteria",
                "",
                "- [ ] Dark mode toggle works",
                "- [ ] Colors are properly themed",
                "",
                "# Design",
                "",
                "Use CSS variables for theming",
                "",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=feature")

            local create_output = '{"id":"bd-200","title":"Add dark mode","issue_type":"feature"}'
            local system_calls = {}

            vim.system = function(cmd_table, _opts)
                table.insert(system_calls, cmd_table)
                if cmd_table[1] == "bd" and cmd_table[2] == "create" then
                    return {
                        wait = function()
                            return { code = 0, stdout = create_output, stderr = "" }
                        end,
                    }
                end
                return {
                    wait = function()
                        return { code = 0, stdout = "", stderr = "" }
                    end,
                }
            end

            core_module.execute_bd = function(args)
                if args[1] == "show" and args[2] == "bd-200" then
                    return {
                        {
                            id = "bd-200",
                            title = "Add dark mode",
                            issue_type = "feature",
                            status = "open",
                            priority = 1,
                            created_at = "2025-11-30T12:00:00Z",
                            updated_at = "2025-11-30T12:00:00Z",
                            closed_at = nil,
                            description = "Add dark mode toggle to settings",
                            acceptance_criteria = "- [ ] Dark mode toggle works\n- [ ] Colors are properly themed",
                            design = "Use CSS variables for theming",
                            labels = { "ui", "frontend" },
                            dependencies = {
                                { id = "bd-50", dependency_type = "blocks" },
                                { id = "bd-60", dependency_type = "blocks" },
                                { id = "bd-100", dependency_type = "parent-child" },
                            },
                        },
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=feature")

            -- Verify create command was called with all fields
            assert.equals(1, #system_calls)
            local cmd = system_calls[1]
            assert.equals("bd", cmd[1])
            assert.equals("create", cmd[2])
            assert.equals("Add dark mode", cmd[3])
            assert.is_true(vim.tbl_contains(cmd, "--type"))
            assert.is_true(vim.tbl_contains(cmd, "feature"))
            assert.is_true(vim.tbl_contains(cmd, "--priority"))
            assert.is_true(vim.tbl_contains(cmd, "1"))
            assert.is_true(vim.tbl_contains(cmd, "--parent"))
            assert.is_true(vim.tbl_contains(cmd, "bd-100"))
            assert.is_true(vim.tbl_contains(cmd, "--deps"))
            assert.is_true(vim.tbl_contains(cmd, "--labels"))

            -- Verify buffer was renamed
            local new_name = vim.api.nvim_buf_get_name(test_bufnr)
            assert.equals("beads://issue/bd-200", new_name)
        end)

        it("should show error when title is missing", function()
            local buffer_content = {
                "---",
                "id: (new)",
                "title: ",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=task")

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=task")

            -- Verify error notification
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Title is required") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)

            -- Verify buffer name was not changed
            local name = vim.api.nvim_buf_get_name(test_bufnr)
            assert.is_true(name:match("beads://issue/new") ~= nil)
        end)

        it("should show error when title is still (new)", function()
            local buffer_content = {
                "---",
                "id: (new)",
                "title: (new)",
                "type: task",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=task")

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=task")

            -- Verify error notification
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Title is required") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)
        end)

        it("should show error when bd create command fails", function()
            local buffer_content = {
                "---",
                "id: (new)",
                "title: Test issue",
                "type: bug",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=bug")

            -- Mock failing system call
            vim.system = function(cmd_table, _opts)
                if cmd_table[1] == "bd" and cmd_table[2] == "create" then
                    return {
                        wait = function()
                            return { code = 1, stdout = "", stderr = "Error: Database connection failed" }
                        end,
                    }
                end
                return {
                    wait = function()
                        return { code = 0, stdout = "", stderr = "" }
                    end,
                }
            end

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=bug")

            -- Verify error notification
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Failed to create issue") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)

            -- Verify buffer name was not changed
            local name = vim.api.nvim_buf_get_name(test_bufnr)
            assert.is_true(name:match("beads://issue/new") ~= nil)
        end)

        it("should reload buffer with authoritative data after creation", function()
            local buffer_content = {
                "---",
                "id: (new)",
                "title: New feature",
                "type: feature",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=feature")

            local create_output = '{"id":"bd-999","title":"New feature","issue_type":"feature"}'

            vim.system = function(cmd_table, _opts)
                if cmd_table[1] == "bd" and cmd_table[2] == "create" then
                    -- mock_shell_error no longer used
                    return {
                        wait = function()
                            return { code = 0, stdout = create_output, stderr = "" }
                        end,
                    }
                end
                return ""
            end

            core_module.execute_bd = function(args)
                if args[1] == "show" and args[2] == "bd-999" then
                    return {
                        {
                            id = "bd-999",
                            title = "New feature",
                            issue_type = "feature",
                            status = "open",
                            priority = 2,
                            created_at = "2025-11-30T15:30:00Z",
                            updated_at = "2025-11-30T15:30:00Z",
                            closed_at = nil,
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            -- Call the handler
            autocmds.handle_new_issue_save(test_bufnr, "beads://issue/new?type=feature")

            -- Verify buffer content was reloaded
            local lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)

            -- Check that timestamps are now present (not null)
            local found_timestamp = false
            for _, line in ipairs(lines) do
                if line:match("created_at: 2025") then
                    found_timestamp = true
                    break
                end
            end
            assert.is_true(found_timestamp)

            -- Verify modified flag was cleared
            local modified = vim.api.nvim_get_option_value("modified", { buf = test_bufnr })
            assert.is_false(modified)
        end)
    end)

    describe("setup", function()
        it("should create autocommand group and register BufWriteCmd", function()
            -- Track autocmd creation
            local autocmd_created = false
            local group_created = false
            local original_create_augroup = vim.api.nvim_create_augroup
            local original_create_autocmd = vim.api.nvim_create_autocmd

            vim.api.nvim_create_augroup = function(name, opts)
                if name == "nvim_beads_buffers" then
                    group_created = true
                    assert.is_true(opts.clear)
                end
                return 123 -- Return a dummy group ID
            end

            vim.api.nvim_create_autocmd = function(event, opts)
                if event == "BufWriteCmd" and opts.pattern == "beads://issue/*" then
                    autocmd_created = true
                    assert.equals(123, opts.group)
                    assert.equals(autocmds.on_buffer_write, opts.callback)
                end
            end

            -- Call setup
            autocmds.setup()

            -- Verify both were created
            assert.is_true(group_created)
            assert.is_true(autocmd_created)

            -- Restore
            vim.api.nvim_create_augroup = original_create_augroup
            vim.api.nvim_create_autocmd = original_create_autocmd
        end)
    end)

    describe("on_buffer_write", function()
        it("should route to handle_new_issue_save for new issue buffers", function()
            local called = false
            local original_handle = autocmds.handle_new_issue_save
            autocmds.handle_new_issue_save = function(bufnr)
                called = true
                assert.equals(test_bufnr, bufnr)
            end

            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/new?type=task")
            autocmds.on_buffer_write({ buf = test_bufnr })

            assert.is_true(called)
            autocmds.handle_new_issue_save = original_handle
        end)

        it("should route to handle_existing_issue_save for existing issue buffers", function()
            local called = false
            local captured_id = nil
            local original_handle = autocmds.handle_existing_issue_save
            autocmds.handle_existing_issue_save = function(bufnr, issue_id)
                called = true
                assert.equals(test_bufnr, bufnr)
                captured_id = issue_id
            end

            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/bd-123")
            autocmds.on_buffer_write({ buf = test_bufnr })

            assert.is_true(called)
            assert.equals("bd-123", captured_id)
            autocmds.handle_existing_issue_save = original_handle
        end)

        it("should show error for invalid buffer name format", function()
            vim.api.nvim_buf_set_name(test_bufnr, "some-other-buffer")
            autocmds.on_buffer_write({ buf = test_bufnr })

            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Invalid buffer name format") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)
        end)
    end)

    describe("existing issue update workflow", function()
        it("should successfully update an existing issue with changes", function()
            -- Create buffer with modified content
            local buffer_content = {
                "---",
                "id: bd-100",
                "title: Updated title",
                "type: bug",
                "status: open",
                "priority: 1",
                "created_at: 2025-11-30T10:00:00Z",
                "updated_at: 2025-11-30T10:00:00Z",
                "closed_at: null",
                "---",
                "",
                "# Description",
                "",
                "Updated description",
                "",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)
            vim.api.nvim_buf_set_name(test_bufnr, "beads://issue/bd-100")

            -- Set the buffer as current in a window to avoid "Invalid buffer id" error
            vim.api.nvim_set_current_buf(test_bufnr)

            -- Mock nvim_buf_line_count since it requires buffer in window
            local original_line_count = vim.api.nvim_buf_line_count
            vim.api.nvim_buf_line_count = function(bufnr)
                return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            end

            -- Mock core.get_issue to return original state
            core_module.get_issue = function(issue_id)
                if issue_id == "bd-100" then
                    return {
                        id = "bd-100",
                        title = "Original title",
                        issue_type = "bug",
                        status = "open",
                        priority = 2,
                        created_at = "2025-11-30T10:00:00Z",
                        updated_at = "2025-11-30T10:00:00Z",
                        closed_at = nil,
                        description = "Original description",
                        labels = {},
                        dependencies = {},
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            -- Track update commands
            local update_commands = {}
            vim.system = function(cmd_table, _opts)
                table.insert(update_commands, cmd_table)
                return {
                    wait = function()
                        return { code = 0, stdout = "", stderr = "" }
                    end,
                }
            end

            -- Mock core.execute_bd for reload
            core_module.execute_bd = function(args)
                if args[1] == "show" and args[2] == "bd-100" then
                    return {
                        {
                            id = "bd-100",
                            title = "Updated title",
                            issue_type = "bug",
                            status = "open",
                            priority = 1,
                            created_at = "2025-11-30T10:00:00Z",
                            updated_at = "2025-11-30T10:00:00Z",
                            closed_at = nil,
                            description = "Updated description",
                            labels = {},
                            dependencies = {},
                        },
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            -- Call the handler
            autocmds.handle_existing_issue_save(test_bufnr, "bd-100")

            -- Restore mocked function
            vim.api.nvim_buf_line_count = original_line_count

            -- Verify update command was called
            assert.is_true(#update_commands > 0)
            local found_update = false
            for _, cmd in ipairs(update_commands) do
                if cmd[1] == "bd" and cmd[2] == "update" and cmd[3] == "bd-100" then
                    found_update = true
                    break
                end
            end
            assert.is_true(found_update)

            -- Verify success notification
            local found_success = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Issue saved successfully") then
                    found_success = true
                    break
                end
            end
            assert.is_true(found_success)
        end)

        it("should handle no changes detected", function()
            -- Create buffer with same content as original
            local buffer_content = {
                "---",
                "id: bd-100",
                "title: Same title",
                "type: bug",
                "status: open",
                "priority: 2",
                "created_at: 2025-11-30T10:00:00Z",
                "updated_at: 2025-11-30T10:00:00Z",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)

            core_module.get_issue = function(issue_id)
                if issue_id == "bd-100" then
                    return {
                        id = "bd-100",
                        title = "Same title",
                        issue_type = "bug",
                        status = "open",
                        priority = 2,
                        created_at = "2025-11-30T10:00:00Z",
                        updated_at = "2025-11-30T10:00:00Z",
                        labels = {},
                        dependencies = {},
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            autocmds.handle_existing_issue_save(test_bufnr, "bd-100")

            -- Verify "No changes detected" notification
            local found_no_changes = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("No changes detected") then
                    found_no_changes = true
                    break
                end
            end
            assert.is_true(found_no_changes)
        end)

        it("should handle failed fetch of original issue", function()
            local buffer_content = {
                "---",
                "id: bd-999",
                "title: Test",
                "type: bug",
                "status: open",
                "priority: 2",
                "created_at: null",
                "updated_at: null",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)

            core_module.get_issue = function(_issue_id)
                return nil, "Issue not found in database"
            end

            autocmds.handle_existing_issue_save(test_bufnr, "bd-999")

            -- Verify error notification
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Issue not found") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)
        end)

        it("should handle command execution failure", function()
            local buffer_content = {
                "---",
                "id: bd-100",
                "title: Updated title",
                "type: bug",
                "status: open",
                "priority: 1",
                "created_at: 2025-11-30T10:00:00Z",
                "updated_at: 2025-11-30T10:00:00Z",
                "closed_at: null",
                "---",
            }

            vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, buffer_content)

            core_module.get_issue = function(issue_id)
                if issue_id == "bd-100" then
                    return {
                        id = "bd-100",
                        title = "Original title",
                        issue_type = "bug",
                        status = "open",
                        priority = 2,
                        created_at = "2025-11-30T10:00:00Z",
                        updated_at = "2025-11-30T10:00:00Z",
                        labels = {},
                        dependencies = {},
                    },
                        nil
                end
                return nil, "Issue not found"
            end

            vim.system = function(_cmd_table, _opts)
                return {
                    wait = function()
                        return { code = 1, stdout = "", stderr = "Database error" }
                    end,
                }
            end

            autocmds.handle_existing_issue_save(test_bufnr, "bd-100")

            -- Verify error notification
            local found_error = false
            for _, notif in ipairs(env.notifications) do
                if notif.message:match("Command failed") and notif.level == vim.log.levels.ERROR then
                    found_error = true
                    break
                end
            end
            assert.is_true(found_error)
        end)
    end)
end)
