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

    describe("parse_list_filters", function()
        it("should handle no arguments", function()
            local filters, err = core.parse_list_filters({})
            assert.is_nil(err)
            assert.same({ status = "open", type = nil }, filters)
        end)

        it("should handle nil arguments", function()
            local filters, err = core.parse_list_filters(nil)
            assert.is_nil(err)
            assert.same({ status = "open", type = nil }, filters)
        end)

        it("should parse a single status argument", function()
            local filters, err = core.parse_list_filters({ "open" })
            assert.is_nil(err)
            assert.same({ status = "open", type = nil }, filters)
        end)

        it("should parse a single type argument", function()
            local filters, err = core.parse_list_filters({ "bug" })
            assert.is_nil(err)
            assert.same({ status = nil, type = "bug" }, filters)
        end)

        it("should parse a plural type argument", function()
            local filters, err = core.parse_list_filters({ "bugs" })
            assert.is_nil(err)
            assert.same({ status = nil, type = "bug" }, filters)
        end)

        it("should parse status and type arguments", function()
            local filters, err = core.parse_list_filters({ "open", "features" })
            assert.is_nil(err)
            assert.same({ status = "open", type = "feature" }, filters)
        end)

        it("should parse type and status arguments (order-independent)", function()
            local filters, err = core.parse_list_filters({ "task", "closed" })
            assert.is_nil(err)
            assert.same({ status = "closed", type = "task" }, filters)
        end)

        it("should handle 'all' for status", function()
            local filters, err = core.parse_list_filters({ "all", "bug" })
            assert.is_nil(err)
            assert.same({ status = "all", type = "bug" }, filters)
        end)

        it("should handle 'all' for type", function()
            local filters, err = core.parse_list_filters({ "open", "all" })
            assert.is_nil(err)
            assert.same({ status = "open", type = "all" }, filters)
        end)

        it("should handle 'all' for both status and type", function()
            local filters, err = core.parse_list_filters({ "all", "all" })
            assert.is_nil(err)
            assert.same({ status = "all", type = "all" }, filters)
        end)

        it("should return an error for an invalid argument", function()
            local filters, err = core.parse_list_filters({ "foobar" })
            assert.is_nil(filters)
            assert.is_not_nil(err)
            assert.matches("Invalid issue status or type 'foobar'", err)
        end)

        it("should return an error for one valid and one invalid argument", function()
            local filters, err = core.parse_list_filters({ "open", "foobar" })
            assert.is_nil(filters)
            assert.is_not_nil(err)
            assert.matches("Invalid issue status or type 'foobar'", err)
        end)

        it("should return an error for duplicate status arguments", function()
            local filters, err = core.parse_list_filters({ "open", "closed" })
            assert.is_nil(filters)
            assert.is_not_nil(err)
            assert.matches("Duplicate issue status 'closed'", err)
        end)

        it("should return an error for duplicate type arguments", function()
            local filters, err = core.parse_list_filters({ "bug", "task" })
            assert.is_nil(filters)
            assert.is_not_nil(err)
            assert.matches("Duplicate issue type 'task'", err)
        end)

        it("should return an error for more than two arguments", function()
            local filters, err = core.parse_list_filters({ "open", "bug", "foobar" })
            assert.is_nil(filters)
            assert.is_not_nil(err)
            assert.matches("Invalid issue status or type 'foobar'", err)
        end)

        it("should be case-insensitive", function()
            local filters, err = core.parse_list_filters({ "OPEN", "BUGS" })
            assert.is_nil(err)
            assert.same({ status = "open", type = "bug" }, filters)
        end)
    end)
end)
