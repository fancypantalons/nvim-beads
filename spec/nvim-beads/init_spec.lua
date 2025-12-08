--- Unit tests for public Lua API (nvim-beads)
--- Tests the public interface that users will call

local env = require("test_utilities.env")

describe("nvim-beads (public API)", function()
    local nvim_beads
    local mock_core
    local mock_buffer

    before_each(function()
        -- Set up mock vim environment
        env.setup_mock_env()

        -- Clear module cache
        package.loaded["nvim-beads"] = nil
        package.loaded["nvim-beads.core"] = nil
        package.loaded["nvim-beads.buffer"] = nil

        -- Create mocks
        mock_core = {
            show_list = function() end,
            show_ready = function() end,
            fetch_template = function() end,
            execute_bd = function() end,
            execute_bd_async = function() end,
            execute_with_ui = function() end,
        }

        mock_buffer = {
            open_issue_buffer = function() end,
            open_new_issue_buffer = function() end,
        }

        -- Mock require to return our mocks
        local original_require = require
        _G.require = function(module)
            if module == "nvim-beads.core" then
                return mock_core
            elseif module == "nvim-beads.buffer" then
                return mock_buffer
            else
                return original_require(module)
            end
        end

        nvim_beads = original_require("nvim-beads")
    end)

    after_each(function()
        -- Restore original require
        package.loaded["nvim-beads"] = nil
        package.loaded["nvim-beads.core"] = nil
        package.loaded["nvim-beads.buffer"] = nil

        -- Teardown mock vim environment
        env.teardown_mock_env()
    end)

    describe("list", function()
        it("should call core.show_list with empty opts when no opts provided", function()
            local called = false
            local received_opts = nil
            mock_core.show_list = function(opts)
                called = true
                received_opts = opts
            end

            nvim_beads.list()

            assert.is_true(called)
            assert.is_not_nil(received_opts)
            assert.same({}, received_opts)
        end)

        it("should call core.show_list with provided opts", function()
            local called = false
            local received_opts = nil
            mock_core.show_list = function(opts)
                called = true
                received_opts = opts
            end

            nvim_beads.list({ status = "open", type = "bug" })

            assert.is_true(called)
            assert.same({ status = "open", type = "bug" }, received_opts)
        end)

        it("should pass all filter options to core.show_list", function()
            local received_opts = nil
            mock_core.show_list = function(opts)
                received_opts = opts
            end

            nvim_beads.list({
                status = "in_progress",
                type = "feature",
                priority = 1,
                assignee = "alice",
            })

            assert.equals("in_progress", received_opts.status)
            assert.equals("feature", received_opts.type)
            assert.equals(1, received_opts.priority)
            assert.equals("alice", received_opts.assignee)
        end)
    end)

    describe("show", function()
        it("should call buffer.open_issue_buffer with issue_id", function()
            local called = false
            local received_id = nil
            mock_buffer.open_issue_buffer = function(id)
                called = true
                received_id = id
            end

            nvim_beads.show("bd-123")

            assert.is_true(called)
            assert.equals("bd-123", received_id)
        end)

        it("should show error when issue_id is nil", function()
            nvim_beads.show(nil)

            assert.equals(1, #env.notifications)
            assert.matches("issue_id is required", env.notifications[1].message)
        end)

        it("should show error when issue_id is empty string", function()
            nvim_beads.show("")

            assert.equals(1, #env.notifications)
            assert.matches("issue_id is required", env.notifications[1].message)
        end)

        it("should show error when issue_id is not a string", function()
            nvim_beads.show(123)

            assert.equals(1, #env.notifications)
            assert.matches("issue_id is required", env.notifications[1].message)
        end)
    end)

    describe("create", function()
        it("should default to 'task' type when no opts provided", function()
            local received_type = nil
            mock_core.fetch_template = function(issue_type)
                received_type = issue_type
                return { type = issue_type }
            end
            mock_buffer.open_new_issue_buffer = function()
                return true
            end

            nvim_beads.create()

            assert.equals("task", received_type)
        end)

        it("should use provided issue type", function()
            local received_type = nil
            mock_core.fetch_template = function(issue_type)
                received_type = issue_type
                return { type = issue_type }
            end
            mock_buffer.open_new_issue_buffer = function()
                return true
            end

            nvim_beads.create({ type = "bug" })

            assert.equals("bug", received_type)
        end)

        it("should fetch template when none provided", function()
            local fetched = false
            mock_core.fetch_template = function()
                fetched = true
                return { type = "feature" }
            end
            mock_buffer.open_new_issue_buffer = function()
                return true
            end

            nvim_beads.create({ type = "feature" })

            assert.is_true(fetched)
        end)

        it("should use provided template without fetching", function()
            local fetched = false
            local received_template = nil
            mock_core.fetch_template = function()
                fetched = true
                return { type = "task" }
            end
            mock_buffer.open_new_issue_buffer = function(_, template)
                received_template = template
                return true
            end

            local custom_template = { title = "Custom", type = "task" }
            nvim_beads.create({ type = "task", template = custom_template })

            assert.is_false(fetched)
            assert.same(custom_template, received_template)
        end)

        it("should show error for invalid issue type", function()
            nvim_beads.create({ type = "invalid" })

            assert.equals(1, #env.notifications)
            assert.matches("invalid issue type", env.notifications[1].message)
        end)

        it("should call buffer.open_new_issue_buffer with type and template", function()
            local received_type = nil
            local received_template = nil
            mock_core.fetch_template = function(issue_type)
                return { type = issue_type, title = "" }
            end
            mock_buffer.open_new_issue_buffer = function(issue_type, template)
                received_type = issue_type
                received_template = template
                return true
            end

            nvim_beads.create({ type = "epic" })

            assert.equals("epic", received_type)
            assert.is_not_nil(received_template)
            assert.equals("epic", received_template.type)
        end)

        it("should show error when buffer creation fails", function()
            mock_core.fetch_template = function()
                return { type = "task" }
            end
            mock_buffer.open_new_issue_buffer = function()
                return false
            end

            nvim_beads.create({ type = "task" })

            assert.equals(1, #env.notifications)
            assert.matches("Failed to create issue buffer", env.notifications[1].message)
        end)
    end)

    describe("ready", function()
        it("should call core.show_ready with empty opts when no opts provided", function()
            local called = false
            local received_opts = nil
            mock_core.show_ready = function(opts)
                called = true
                received_opts = opts
            end

            nvim_beads.ready()

            assert.is_true(called)
            assert.same({}, received_opts)
        end)

        it("should call core.show_ready with provided opts", function()
            local received_opts = nil
            mock_core.show_ready = function(opts)
                received_opts = opts
            end

            nvim_beads.ready({ type = "bug", priority = 0 })

            assert.equals("bug", received_opts.type)
            assert.equals(0, received_opts.priority)
        end)
    end)

    describe("execute", function()
        it("should call core.execute_bd synchronously by default", function()
            local called = false
            local received_args = nil
            mock_core.execute_bd = function(args)
                called = true
                received_args = args
                return { result = "success" }
            end

            local result = nvim_beads.execute({ "show", "bd-123" })

            assert.is_true(called)
            assert.same({ "show", "bd-123" }, received_args)
            assert.same({ result = "success" }, result)
        end)

        it("should call core.execute_bd_async when async=true", function()
            local called = false
            local received_args = nil
            local received_callback = nil
            mock_core.execute_bd_async = function(args, callback)
                called = true
                received_args = args
                received_callback = callback
            end

            local callback = function() end
            local result = nvim_beads.execute({ "list" }, { async = true, callback = callback })

            assert.is_true(called)
            assert.same({ "list" }, received_args)
            assert.equals(callback, received_callback)
            assert.is_nil(result) -- Async returns nil
        end)

        it("should error when args is not a table (sync)", function()
            assert.has_error(function()
                nvim_beads.execute("not a table")
            end, "nvim-beads.execute: args must be a table")
        end)

        it("should error when async=true but no callback provided", function()
            assert.has_error(function()
                nvim_beads.execute({ "list" }, { async = true })
            end, "nvim-beads.execute: callback required for async execution")
        end)

        it("should error when async=true and callback is not a function", function()
            assert.has_error(function()
                nvim_beads.execute({ "list" }, { async = true, callback = "not a function" })
            end, "nvim-beads.execute: callback required for async execution")
        end)

        it("should call callback with error when args is invalid (async)", function()
            local callback_called = false
            local callback_result = nil
            local callback_error = nil

            vim.schedule = function(fn)
                fn()
            end

            nvim_beads.execute("not a table", {
                async = true,
                callback = function(result, err)
                    callback_called = true
                    callback_result = result
                    callback_error = err
                end,
            })

            assert.is_true(callback_called)
            assert.is_nil(callback_result)
            assert.matches("args must be a table", callback_error)
        end)
    end)

    describe("execute_with_ui", function()
        it("should call core.execute_with_ui with args", function()
            local called = false
            local received_args = nil
            mock_core.execute_with_ui = function(args, _)
                called = true
                received_args = args
            end

            nvim_beads.execute_with_ui({ "list", "--priority", "1" })

            assert.is_true(called)
            assert.same({ "list", "--priority", "1" }, received_args)
        end)

        it("should call core.execute_with_ui with empty opts when none provided", function()
            local received_opts = nil
            mock_core.execute_with_ui = function(_, opts)
                received_opts = opts
            end

            nvim_beads.execute_with_ui({ "ready" })

            assert.is_not_nil(received_opts)
            assert.same({}, received_opts)
        end)

        it("should pass opts to core.execute_with_ui", function()
            local received_opts = nil
            mock_core.execute_with_ui = function(_, opts)
                received_opts = opts
            end

            nvim_beads.execute_with_ui({ "list" }, { some_opt = "value" })

            assert.equals("value", received_opts.some_opt)
        end)

        it("should show error when args is nil", function()
            nvim_beads.execute_with_ui(nil)

            assert.equals(1, #env.notifications)
            assert.matches("args must be a non%-empty table", env.notifications[1].message)
        end)

        it("should show error when args is not a table", function()
            nvim_beads.execute_with_ui("not a table")

            assert.equals(1, #env.notifications)
            assert.matches("args must be a non%-empty table", env.notifications[1].message)
        end)

        it("should show error when args is empty table", function()
            nvim_beads.execute_with_ui({})

            assert.equals(1, #env.notifications)
            assert.matches("args must be a non%-empty table", env.notifications[1].message)
        end)

        it("should work with whitelisted command 'list'", function()
            local called = false
            local received_args = nil
            mock_core.execute_with_ui = function(args, _)
                called = true
                received_args = args
            end

            nvim_beads.execute_with_ui({ "list" })

            assert.is_true(called)
            assert.same({ "list" }, received_args)
        end)

        it("should work with non-whitelisted command 'show'", function()
            local called = false
            local received_args = nil
            mock_core.execute_with_ui = function(args, _)
                called = true
                received_args = args
            end

            nvim_beads.execute_with_ui({ "show", "bd-123" })

            assert.is_true(called)
            assert.same({ "show", "bd-123" }, received_args)
        end)
    end)

    describe("search()", function()
        it("should validate query parameter is non-empty string", function()
            nvim_beads.search("")

            assert.equals(1, #env.notifications)
            assert.matches("query is required", env.notifications[1].message)
        end)

        it("should validate query parameter is a string", function()
            nvim_beads.search(nil)

            assert.equals(1, #env.notifications)
            assert.matches("query is required", env.notifications[1].message)
        end)

        it("should split query into words and call execute_with_ui", function()
            local called = false
            local received_bd_args = nil
            local received_filter = nil
            mock_core.execute_with_ui = function(bd_args, filter)
                called = true
                received_bd_args = bd_args
                received_filter = filter
            end

            nvim_beads.search("foo bar baz")

            assert.is_true(called)
            assert.same({ "search", "foo", "bar", "baz" }, received_bd_args)
            assert.same({}, received_filter)
        end)

        it("should pass status filter to execute_with_ui", function()
            local called = false
            local received_bd_args = nil
            local received_filter = nil
            mock_core.execute_with_ui = function(bd_args, filter)
                called = true
                received_bd_args = bd_args
                received_filter = filter
            end

            nvim_beads.search("query", { status = "open" })

            assert.is_true(called)
            assert.same({ "search", "query" }, received_bd_args)
            assert.same({ status = "open" }, received_filter)
        end)

        it("should pass type filter to execute_with_ui", function()
            local called = false
            local received_bd_args = nil
            local received_filter = nil
            mock_core.execute_with_ui = function(bd_args, filter)
                called = true
                received_bd_args = bd_args
                received_filter = filter
            end

            nvim_beads.search("query", { type = "bug" })

            assert.is_true(called)
            assert.same({ "search", "query" }, received_bd_args)
            assert.same({ type = "bug" }, received_filter)
        end)

        it("should pass combined filters to execute_with_ui", function()
            local called = false
            local received_bd_args = nil
            local received_filter = nil
            mock_core.execute_with_ui = function(bd_args, filter)
                called = true
                received_bd_args = bd_args
                received_filter = filter
            end

            nvim_beads.search("authentication", { status = "open", type = "bug" })

            assert.is_true(called)
            assert.same({ "search", "authentication" }, received_bd_args)
            assert.same({ status = "open", type = "bug" }, received_filter)
        end)

        it("should handle multi-word queries correctly", function()
            local called = false
            local received_bd_args = nil
            mock_core.execute_with_ui = function(bd_args, _)
                called = true
                received_bd_args = bd_args
            end

            nvim_beads.search("fix login bug in authentication")

            assert.is_true(called)
            assert.same({ "search", "fix", "login", "bug", "in", "authentication" }, received_bd_args)
        end)
    end)

    describe("show_under_cursor()", function()
        local mock_navigation

        before_each(function()
            -- Clear navigation module cache
            package.loaded["nvim-beads.navigation"] = nil

            -- Create navigation mock
            mock_navigation = {
                navigate_to_issue_at_cursor = function()
                    return true
                end,
            }

            -- Mock require to return navigation mock
            local original_require = require
            _G.require = function(module)
                if module == "nvim-beads.navigation" then
                    return mock_navigation
                elseif module == "nvim-beads.core" then
                    return mock_core
                elseif module == "nvim-beads.buffer" then
                    return mock_buffer
                else
                    return original_require(module)
                end
            end

            -- Reload nvim-beads with new mocks
            package.loaded["nvim-beads"] = nil
            nvim_beads = original_require("nvim-beads")
        end)

        it("should call navigation.navigate_to_issue_at_cursor with notify_on_miss=true by default", function()
            local called = false
            local received_opts = nil
            mock_navigation.navigate_to_issue_at_cursor = function(opts)
                called = true
                received_opts = opts
                return true
            end

            local success = nvim_beads.show_under_cursor()

            assert.is_true(called)
            assert.is_true(success)
            assert.is_not_nil(received_opts)
            assert.is_true(received_opts.notify_on_miss)
        end)

        it("should pass notify_on_miss=false when explicitly set", function()
            local called = false
            local received_opts = nil
            mock_navigation.navigate_to_issue_at_cursor = function(opts)
                called = true
                received_opts = opts
                return true
            end

            local success = nvim_beads.show_under_cursor({ notify_on_miss = false })

            assert.is_true(called)
            assert.is_true(success)
            assert.is_not_nil(received_opts)
            assert.is_false(received_opts.notify_on_miss)
        end)

        it("should return false when navigation fails", function()
            mock_navigation.navigate_to_issue_at_cursor = function(_opts)
                return false
            end

            local success = nvim_beads.show_under_cursor()

            assert.is_false(success)
        end)

        it("should handle empty opts table", function()
            local called = false
            local received_opts = nil
            mock_navigation.navigate_to_issue_at_cursor = function(opts)
                called = true
                received_opts = opts
                return true
            end

            local success = nvim_beads.show_under_cursor({})

            assert.is_true(called)
            assert.is_true(success)
            -- Should default to notify_on_miss=true
            assert.is_true(received_opts.notify_on_miss)
        end)

        it("should preserve other opts when notify_on_miss not specified", function()
            local called = false
            local received_opts = nil
            mock_navigation.navigate_to_issue_at_cursor = function(opts)
                called = true
                received_opts = opts
                return true
            end

            local success = nvim_beads.show_under_cursor({ some_other_opt = "value" })

            assert.is_true(called)
            assert.is_true(success)
            assert.is_true(received_opts.notify_on_miss)
            assert.equals("value", received_opts.some_other_opt)
        end)
    end)
end)
