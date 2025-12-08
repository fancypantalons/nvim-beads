--- Integration tests for plugin-level commands
--- Tests :BeadsCreateIssue command validation and integration

local env = require("test_utilities.env")

describe("BeadsCreateIssue command", function()
    before_each(function()
        -- Clear module cache
        package.loaded["nvim-beads.core"] = nil

        -- Setup mock environment
        env.setup_mock_env()
    end)

    after_each(function()
        env.teardown_mock_env()
    end)

    describe("argument validation", function()
        it("should show error when no arguments provided", function()
            -- Mock the user command execution
            local command_func = function(opts)
                local args = opts.fargs

                if #args == 0 then
                    vim.notify(
                        "BeadsCreateIssue: missing issue type. Usage: :BeadsCreateIssue <type>",
                        vim.log.levels.ERROR
                    )
                    vim.notify("Valid types: bug, feature, task, epic, chore", vim.log.levels.INFO)
                    return
                end
            end

            command_func({ fargs = {} })

            assert.equals(2, #env.notifications)
            assert.matches("missing issue type", env.notifications[1].message)
            assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
            assert.matches("Valid types", env.notifications[2].message)
        end)

        it("should show error when too many arguments provided", function()
            local command_func = function(opts)
                local args = opts.fargs

                if #args > 1 then
                    vim.notify(
                        "BeadsCreateIssue: too many arguments. Usage: :BeadsCreateIssue <type>",
                        vim.log.levels.ERROR
                    )
                    return
                end
            end

            command_func({ fargs = { "task", "extra" } })

            assert.equals(1, #env.notifications)
            assert.matches("too many arguments", env.notifications[1].message)
            assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
        end)
    end)

    describe("valid issue type handling", function()
        it('should accept "bug" as valid type', function()
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

            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("bug")

            assert.is_nil(err)
            assert.is_not_nil(template)
        end)

        it('should accept "feature" as valid type', function()
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

            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("feature")

            assert.is_nil(err)
            assert.is_not_nil(template)
        end)

        it('should accept "task" as valid type', function()
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

            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("task")

            assert.is_nil(err)
            assert.is_not_nil(template)
        end)

        it('should accept "epic" as valid type', function()
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

            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("epic")

            assert.is_nil(err)
            assert.is_not_nil(template)
        end)

        it('should accept "chore" as valid type', function()
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

            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("chore")

            assert.is_nil(err)
            assert.is_not_nil(template)
        end)
    end)

    describe("invalid issue type handling", function()
        it("should reject invalid issue type", function()
            local core = require("nvim-beads.core")
            local template, err = core.fetch_template("invalid")

            assert.is_nil(template)
            assert.is_not_nil(err)
            assert.matches("Invalid issue type", err)
        end)

        it("should show error notification for invalid type", function()
            local command_func = function(opts)
                local args = opts.fargs
                local issue_type = args[1]

                local core = require("nvim-beads.core")
                local _, err = core.fetch_template(issue_type)

                if err then
                    vim.notify("BeadsCreateIssue: " .. err, vim.log.levels.ERROR)
                    return
                end
            end

            command_func({ fargs = { "invalid" } })

            assert.equals(1, #env.notifications)
            assert.matches("Invalid issue type", env.notifications[1].message)
            assert.equals(vim.log.levels.ERROR, env.notifications[1].level)
        end)
    end)

    describe("command completion", function()
        it("should provide all valid types as completion candidates", function()
            local complete_func = function(arg_lead, _, _)
                local valid_types = { "bug", "feature", "task", "epic", "chore" }
                return vim.tbl_filter(function(type)
                    return type:find(arg_lead) == 1
                end, valid_types)
            end

            local results = complete_func("", ":BeadsCreateIssue ", 19)

            assert.equals(5, #results)
            assert.is_true(vim.tbl_contains(results, "bug"))
            assert.is_true(vim.tbl_contains(results, "feature"))
            assert.is_true(vim.tbl_contains(results, "task"))
            assert.is_true(vim.tbl_contains(results, "epic"))
            assert.is_true(vim.tbl_contains(results, "chore"))
        end)

        it('should filter completion by prefix: "ta"', function()
            local complete_func = function(arg_lead, _, _)
                local valid_types = { "bug", "feature", "task", "epic", "chore" }
                return vim.tbl_filter(function(type)
                    return type:find(arg_lead) == 1
                end, valid_types)
            end

            local results = complete_func("ta", ":BeadsCreateIssue ta", 21)

            assert.equals(1, #results)
            assert.equals("task", results[1])
        end)

        it('should filter completion by prefix: "f"', function()
            local complete_func = function(arg_lead, _, _)
                local valid_types = { "bug", "feature", "task", "epic", "chore" }
                return vim.tbl_filter(function(type)
                    return type:find(arg_lead) == 1
                end, valid_types)
            end

            local results = complete_func("f", ":BeadsCreateIssue f", 20)

            assert.equals(1, #results)
            assert.equals("feature", results[1])
        end)

        it("should return empty list for no matches", function()
            local complete_func = function(arg_lead, _, _)
                local valid_types = { "bug", "feature", "task", "epic", "chore" }
                return vim.tbl_filter(function(type)
                    return type:find(arg_lead) == 1
                end, valid_types)
            end

            local results = complete_func("xyz", ":BeadsCreateIssue xyz", 22)

            assert.equals(0, #results)
        end)
    end)
end)
