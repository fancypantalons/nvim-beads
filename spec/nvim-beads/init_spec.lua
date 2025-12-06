--- Unit tests for public Lua API (nvim-beads)
--- Tests the public interface that users will call

describe("nvim-beads (public API)", function()
    local nvim_beads
    local mock_core
    local mock_buffer

    before_each(function()
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
            local notified = false
            local notify_msg = nil
            vim.notify = function(msg, _level)
                notified = true
                notify_msg = msg
            end

            nvim_beads.show(nil)

            assert.is_true(notified)
            assert.matches("issue_id is required", notify_msg)
        end)

        it("should show error when issue_id is empty string", function()
            local notified = false
            local notify_msg = nil
            vim.notify = function(msg, _level)
                notified = true
                notify_msg = msg
            end

            nvim_beads.show("")

            assert.is_true(notified)
            assert.matches("issue_id is required", notify_msg)
        end)

        it("should show error when issue_id is not a string", function()
            local notified = false
            local notify_msg = nil
            vim.notify = function(msg, _level)
                notified = true
                notify_msg = msg
            end

            nvim_beads.show(123)

            assert.is_true(notified)
            assert.matches("issue_id is required", notify_msg)
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
            local notified = false
            local notify_msg = nil
            vim.notify = function(msg, _level)
                notified = true
                notify_msg = msg
            end

            nvim_beads.create({ type = "invalid" })

            assert.is_true(notified)
            assert.matches("invalid issue type", notify_msg)
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
            local notified = false
            local notify_msg = nil
            vim.notify = function(msg, _level)
                notified = true
                notify_msg = msg
            end

            mock_core.fetch_template = function()
                return { type = "task" }
            end
            mock_buffer.open_new_issue_buffer = function()
                return false
            end

            nvim_beads.create({ type = "task" })

            assert.is_true(notified)
            assert.matches("Failed to create issue buffer", notify_msg)
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
end)
