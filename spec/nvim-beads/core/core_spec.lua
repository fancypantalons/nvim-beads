--- Unit tests for nvim-beads core module
--- Tests use mocked vim.system to verify JSON parsing and error handling

describe("nvim-beads.core", function()
    local core
    local original_vim_system

    before_each(function()
        -- Clear the module cache to get fresh instance
        package.loaded["nvim-beads.core"] = nil
        core = require("nvim-beads.core")

        -- Save original vim.system
        original_vim_system = vim.system
    end)

    after_each(function()
        -- Restore original vim.system
        vim.system = original_vim_system
    end)

    describe("execute_bd", function()
        describe("argument validation", function()
            it("should return error when args is not a table", function()
                local result, err = core.execute_bd("not a table")
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("args must be a table", err)
            end)

            it("should return error when args is nil", function()
                local result, err = core.execute_bd(nil)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("args must be a table", err)
            end)

            it("should return error when args is a number", function()
                local result, err = core.execute_bd(42)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("args must be a table", err)
            end)
        end)

        describe("successful command execution", function()
            it("should parse JSON output correctly", function()
                -- Mock successful command execution
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": [{"id": "bd-1", "title": "Test issue"}]}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.is_table(result)
                assert.is_table(result.result)
                assert.equals("bd-1", result.result[1].id)
                assert.equals("Test issue", result.result[1].title)
            end)

            it("should automatically add --json flag if not present", function()
                local called_with_json = false

                vim.system = function(cmd, _)
                    -- Check if --json flag is present
                    for _, arg in ipairs(cmd) do
                        if arg == "--json" then
                            called_with_json = true
                            break
                        end
                    end

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.execute_bd({ "ready" })
                assert.is_nil(err)
                assert.is_true(called_with_json)
            end)

            it("should not duplicate --json flag if already present", function()
                local json_count = 0

                vim.system = function(cmd, _)
                    -- Count how many times --json appears
                    for _, arg in ipairs(cmd) do
                        if arg == "--json" then
                            json_count = json_count + 1
                        end
                    end

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.execute_bd({ "ready", "--json" })
                assert.is_nil(err)
                assert.equals(1, json_count)
            end)

            it("should pass text=true option to vim.system", function()
                local received_opts = nil

                vim.system = function(_, opts)
                    received_opts = opts

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.execute_bd({ "ready" })
                assert.is_nil(err)
                assert.is_not_nil(received_opts)
                assert.is_true(received_opts.text)
            end)

            it("should allow custom options to override defaults", function()
                local received_opts = nil

                vim.system = function(_, opts)
                    received_opts = opts

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": []}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.execute_bd({ "ready" }, { timeout = 5000 })
                assert.is_nil(err)
                assert.is_not_nil(received_opts)
                assert.equals(5000, received_opts.timeout)
                assert.is_true(received_opts.text) -- Default should still be there
            end)
        end)

        describe("command failure handling", function()
            it("should return error when command fails with non-zero exit code", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = "",
                                stderr = "Command not found",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "invalid_command" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("bd command failed", err)
                assert.matches("exit code 1", err)
                assert.matches("Command not found", err)
            end)

            it("should handle empty stderr in error message", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 127,
                                stdout = "",
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "missing_command" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("exit code 127", err)
                assert.matches("no error output", err)
            end)

            it("should handle nil stderr in error message", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = "",
                                stderr = nil,
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "failing_command" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("no error output", err)
            end)
        end)

        describe("JSON parsing error handling", function()
            it("should return error when output is not valid JSON", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = "This is not JSON",
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Failed to parse JSON output", err)
            end)

            it("should return error when JSON is incomplete", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": [',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Failed to parse JSON output", err)
            end)

            it("should return error when JSON is empty string", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = "",
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Failed to parse JSON output", err)
            end)
        end)

        describe("complex JSON structures", function()
            it("should parse nested objects correctly", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": {"nested": {"deep": "value"}}}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("value", result.result.nested.deep)
            end)

            it("should parse arrays with multiple elements", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"issues": [{"id": "bd-1"}, {"id": "bd-2"}, {"id": "bd-3"}]}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "list" })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals(3, #result.issues)
                assert.equals("bd-1", result.issues[1].id)
                assert.equals("bd-2", result.issues[2].id)
                assert.equals("bd-3", result.issues[3].id)
            end)

            it("should handle null values in JSON", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"result": null}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.execute_bd({ "ready" })
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.is_table(result)
            end)
        end)
    end)

    describe("fetch_template", function()
        describe("issue type validation", function()
            it("should accept valid issue type: bug", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "bug"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("bug")
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)

            it("should accept valid issue type: feature", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "feature"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("feature")
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)

            it("should accept valid issue type: task", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "task"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("task")
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)

            it("should accept valid issue type: epic", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "epic"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("epic")
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)

            it("should accept valid issue type: chore", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "chore"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("chore")
                assert.is_nil(err)
                assert.is_not_nil(result)
            end)

            it("should reject invalid issue type", function()
                local result, err = core.fetch_template("invalid")
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Invalid issue type 'invalid'", err)
                assert.matches("bug, feature, task, epic, chore", err)
            end)

            it("should reject empty string issue type", function()
                local result, err = core.fetch_template("")
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Invalid issue type", err)
            end)

            it("should reject nil issue type", function()
                local result, err = core.fetch_template(nil)
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Invalid issue type", err)
            end)
        end)

        describe("command construction", function()
            it("should execute correct bd command with type", function()
                local executed_cmd = nil

                vim.system = function(cmd, _)
                    executed_cmd = cmd

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "task"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.fetch_template("task")
                assert.is_nil(err)
                assert.is_not_nil(executed_cmd)
                assert.equals("bd", executed_cmd[1])
                assert.equals("template", executed_cmd[2])
                assert.equals("show", executed_cmd[3])
                assert.equals("task", executed_cmd[4])
            end)

            it("should include --json flag in command", function()
                local executed_cmd = nil

                vim.system = function(cmd, _)
                    executed_cmd = cmd

                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "bug"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local _, err = core.fetch_template("bug")
                assert.is_nil(err)
                assert.is_not_nil(executed_cmd)

                local has_json = false
                for _, arg in ipairs(executed_cmd) do
                    if arg == "--json" then
                        has_json = true
                        break
                    end
                end
                assert.is_true(has_json)
            end)
        end)

        describe("template parsing", function()
            it("should parse template JSON correctly", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "Test Title", "type": "task", '
                                    .. '"priority": 2, "description": "Test description"}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("task")
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("Test Title", result.title)
                assert.equals("task", result.type)
                assert.equals(2, result.priority)
                assert.equals("Test description", result.description)
            end)

            it("should handle template with all fields", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = '{"title": "", "type": "feature", '
                                    .. '"priority": 1, "description": "Desc", '
                                    .. '"design": "Design", "acceptance_criteria": "AC", '
                                    .. '"labels": ["label1"], "parent": null, "dependencies": []}',
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("feature")
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("feature", result.type)
                assert.equals(1, result.priority)
                assert.equals("Desc", result.description)
                assert.equals("Design", result.design)
                assert.equals("AC", result.acceptance_criteria)
            end)
        end)

        describe("error handling", function()
            it("should return default template when bd command fails (no template found)", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = "",
                                stderr = "Template not found",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("task")
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("", result.title)
                assert.equals("task", result.type)
                assert.equals(2, result.priority)
                assert.equals("", result.description)
                assert.equals("", result.acceptance_criteria)
                assert.equals("", result.design)
            end)

            it("should return default template with correct type for bug", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = "",
                                stderr = "Template not found",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("bug")
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("bug", result.type)
            end)

            it("should return default template with correct type for feature", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 1,
                                stdout = "",
                                stderr = "Template not found",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("feature")
                assert.is_nil(err)
                assert.is_not_nil(result)
                assert.equals("feature", result.type)
            end)

            it("should return error when JSON parsing fails", function()
                vim.system = function(_, _)
                    return {
                        wait = function()
                            return {
                                code = 0,
                                stdout = "Invalid JSON",
                                stderr = "",
                            }
                        end,
                    }
                end

                local result, err = core.fetch_template("task")
                assert.is_nil(result)
                assert.is_not_nil(err)
                assert.matches("Failed to parse JSON output", err)
            end)
        end)
    end)

    describe("execute_bd_async", function()
        describe("argument validation", function()
            it("should call callback with error when callback is not a function", function()
                -- This should error before calling vim.system
                local success = pcall(function()
                    core.execute_bd_async({ "ready" }, "not a function")
                end)
                local error_caught = not success
                assert.is_true(error_caught)
            end)

            it("should call callback with error when args is not a table", function()
                local callback_result = nil
                local callback_error = nil

                core.execute_bd_async("not a table", function(result, err)
                    callback_result = result
                    callback_error = err
                end)

                -- vim.schedule should have been called, need to process it
                vim.wait(10)

                assert.is_nil(callback_result)
                assert.is_not_nil(callback_error)
                assert.matches("args must be a table", callback_error)
            end)
        end)

        describe("successful async execution", function()
            it("should parse JSON and call callback with result", function()
                local callback_result = nil
                local callback_error = nil
                local callback_called = false

                vim.system = function(_, _, callback)
                    -- Simulate async call
                    vim.schedule(function()
                        callback({
                            code = 0,
                            stdout = '{"issues": [{"id": "bd-1", "title": "Async issue"}]}',
                            stderr = "",
                        })
                    end)
                end

                core.execute_bd_async({ "ready" }, function(result, err)
                    callback_called = true
                    callback_result = result
                    callback_error = err
                end)

                -- Wait for async callback
                vim.wait(100, function()
                    return callback_called
                end)

                assert.is_true(callback_called)
                assert.is_nil(callback_error)
                assert.is_not_nil(callback_result)
                assert.equals("bd-1", callback_result.issues[1].id)
                assert.equals("Async issue", callback_result.issues[1].title)
            end)

            it("should add --json flag automatically", function()
                local cmd_has_json = false

                vim.system = function(cmd, _, callback)
                    for _, arg in ipairs(cmd) do
                        if arg == "--json" then
                            cmd_has_json = true
                            break
                        end
                    end

                    vim.schedule(function()
                        callback({
                            code = 0,
                            stdout = "{}",
                            stderr = "",
                        })
                    end)
                end

                local callback_called = false
                core.execute_bd_async({ "ready" }, function()
                    callback_called = true
                end)

                vim.wait(100, function()
                    return callback_called
                end)

                assert.is_true(cmd_has_json)
            end)
        end)

        describe("async error handling", function()
            it("should call callback with error when command fails", function()
                local callback_result = nil
                local callback_error = nil
                local callback_called = false

                vim.system = function(_, _, callback)
                    vim.schedule(function()
                        callback({
                            code = 1,
                            stdout = "",
                            stderr = "Command failed",
                        })
                    end)
                end

                core.execute_bd_async({ "failing" }, function(result, err)
                    callback_called = true
                    callback_result = result
                    callback_error = err
                end)

                vim.wait(100, function()
                    return callback_called
                end)

                assert.is_true(callback_called)
                assert.is_nil(callback_result)
                assert.is_not_nil(callback_error)
                assert.matches("bd command failed", callback_error)
                assert.matches("Command failed", callback_error)
            end)

            it("should call callback with error when JSON parsing fails", function()
                local callback_result = nil
                local callback_error = nil
                local callback_called = false

                vim.system = function(_, _, callback)
                    vim.schedule(function()
                        callback({
                            code = 0,
                            stdout = "Invalid JSON",
                            stderr = "",
                        })
                    end)
                end

                core.execute_bd_async({ "ready" }, function(result, err)
                    callback_called = true
                    callback_result = result
                    callback_error = err
                end)

                vim.wait(100, function()
                    return callback_called
                end)

                assert.is_true(callback_called)
                assert.is_nil(callback_result)
                assert.is_not_nil(callback_error)
                assert.matches("Failed to parse JSON output", callback_error)
            end)
        end)
    end)

    describe("show_issues", function()
        it("should load telescope extension and call show_issues", function()
            local show_issues_called = false
            local show_issues_bd_args = nil
            local show_issues_opts = nil

            package.loaded["telescope"] = {
                extensions = {
                    nvim_beads = {
                        show_issues = function(bd_args, opts)
                            show_issues_called = true
                            show_issues_bd_args = bd_args
                            show_issues_opts = opts
                        end,
                    },
                },
                load_extension = function() end,
            }

            core.show_issues({ "list", "--status", "open" }, { type = "bug" })

            assert.is_true(show_issues_called)
            assert.same({ "list", "--status", "open" }, show_issues_bd_args)
            assert.same({ type = "bug" }, show_issues_opts)
        end)

        it("should load telescope extension if not already loaded", function()
            local load_extension_called = false
            local extension_name = nil

            package.loaded["telescope"] = {
                extensions = {},
                load_extension = function(name)
                    load_extension_called = true
                    extension_name = name
                    -- Simulate extension being loaded
                    package.loaded["telescope"].extensions.nvim_beads = {
                        show_issues = function() end,
                    }
                end,
            }

            core.show_issues({ "ready" }, {})

            assert.is_true(load_extension_called)
            assert.equals("nvim_beads", extension_name)
        end)

        it("should show error when telescope is not installed", function()
            local notify_called = false
            local notify_msg = nil
            local notify_level = nil

            local original_notify = vim.notify
            local original_pcall = _G.pcall

            vim.notify = function(msg, level)
                notify_called = true
                notify_msg = msg
                notify_level = level
            end

            -- Mock pcall to make require("telescope") fail
            _G.pcall = function(fn, ...)
                if fn == require and select(1, ...) == "telescope" then
                    return false, "module 'telescope' not found"
                end
                return original_pcall(fn, ...)
            end

            core.show_issues({ "list" }, {})

            vim.notify = original_notify
            _G.pcall = original_pcall

            assert.is_true(notify_called)
            assert.matches("Telescope not found", notify_msg)
            assert.equals(vim.log.levels.ERROR, notify_level)
        end)

        it("should handle nil opts", function()
            local show_issues_opts = "NOT_SET"

            package.loaded["telescope"] = {
                extensions = {
                    nvim_beads = {
                        show_issues = function(_, opts)
                            show_issues_opts = opts
                        end,
                    },
                },
                load_extension = function() end,
            }

            core.show_issues({ "list" }, nil)

            assert.same({}, show_issues_opts)
        end)
    end)

    describe("execute_with_ui", function()
        local original_telescope
        local original_util

        before_each(function()
            -- Save originals
            original_telescope = package.loaded["telescope"]
            original_util = package.loaded["nvim-beads.util"]

            -- Mock telescope
            package.loaded["telescope"] = {
                extensions = {
                    nvim_beads = {
                        show_issues = function() end,
                    },
                },
                load_extension = function() end,
            }

            -- Mock util
            package.loaded["nvim-beads.util"] = {
                execute_command_in_scratch_buffer = function() end,
            }
        end)

        after_each(function()
            -- Restore originals
            package.loaded["telescope"] = original_telescope
            package.loaded["nvim-beads.util"] = original_util
        end)

        it("should route whitelisted 'list' command to telescope", function()
            local show_issues_called = false
            local show_issues_args = nil

            package.loaded["telescope"].extensions.nvim_beads.show_issues = function(bd_args)
                show_issues_called = true
                show_issues_args = bd_args
            end

            core.execute_with_ui({ "list", "--status", "open" })

            assert.is_true(show_issues_called)
            assert.same({ "list", "--status", "open" }, show_issues_args)
        end)

        it("should route whitelisted 'ready' command to telescope", function()
            local show_issues_called = false

            package.loaded["telescope"].extensions.nvim_beads.show_issues = function()
                show_issues_called = true
            end

            core.execute_with_ui({ "ready" })

            assert.is_true(show_issues_called)
        end)

        it("should route whitelisted 'search' command to telescope", function()
            local show_issues_called = false

            package.loaded["telescope"].extensions.nvim_beads.show_issues = function()
                show_issues_called = true
            end

            core.execute_with_ui({ "search", "keyword" })

            assert.is_true(show_issues_called)
        end)

        it("should route whitelisted 'blocked' command to telescope", function()
            local show_issues_called = false

            package.loaded["telescope"].extensions.nvim_beads.show_issues = function()
                show_issues_called = true
            end

            core.execute_with_ui({ "blocked" })

            assert.is_true(show_issues_called)
        end)

        it("should route non-whitelisted 'show' command to terminal", function()
            local terminal_called = false
            local terminal_command = nil
            local terminal_args = nil

            package.loaded["nvim-beads.util"].execute_command_in_scratch_buffer = function(cmd, args)
                terminal_called = true
                terminal_command = cmd
                terminal_args = args
            end

            core.execute_with_ui({ "show", "bd-123" })

            assert.is_true(terminal_called)
            assert.equals("show", terminal_command)
            assert.same({ "bd-123" }, terminal_args)
        end)

        it("should route 'create' command to terminal", function()
            local terminal_called = false

            package.loaded["nvim-beads.util"].execute_command_in_scratch_buffer = function()
                terminal_called = true
            end

            core.execute_with_ui({ "create", "New issue" })

            assert.is_true(terminal_called)
        end)

        it("should show error when args is empty", function()
            local notify_called = false
            local notify_msg = nil

            local original_notify = vim.notify
            vim.notify = function(msg, _)
                notify_called = true
                notify_msg = msg
            end

            -- Reload core to ensure it picks up our vim.notify mock
            package.loaded["nvim-beads.core"] = nil
            local test_core = require("nvim-beads.core")

            test_core.execute_with_ui({})

            vim.notify = original_notify

            assert.is_true(notify_called, "vim.notify should have been called, got: " .. tostring(notify_called))
            assert.is_not_nil(notify_msg, "notify message should not be nil")
            assert.is_string(notify_msg, "notify_msg should be a string, got: " .. type(notify_msg))
            assert.matches("non%-empty table", notify_msg)
        end)

        it("should show error when args is not a table", function()
            local notify_called = false

            local original_notify = vim.notify
            vim.notify = function()
                notify_called = true
            end

            core.execute_with_ui("not a table")

            vim.notify = original_notify

            assert.is_true(notify_called)
        end)

        it("should handle nil opts", function()
            local show_issues_opts = "NOT_SET"

            package.loaded["telescope"].extensions.nvim_beads.show_issues = function(_, opts)
                show_issues_opts = opts
            end

            core.execute_with_ui({ "list" }, nil)

            assert.same({}, show_issues_opts)
        end)
    end)
end)
