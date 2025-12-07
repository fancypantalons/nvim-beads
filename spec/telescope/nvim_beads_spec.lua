describe("telescope nvim_beads extension", function()
    local telescope_picker
    local telescope_finders
    local extension

    local original_vim_system

    -- Sample issue data
    local sample_issues = {
        { id = "bd-1", title = "Open bug", status = "open", issue_type = "bug" },
        { id = "bd-2", title = "Closed bug", status = "closed", issue_type = "bug" },
        { id = "bd-3", title = "Open feature", status = "open", issue_type = "feature" },
        { id = "bd-4", title = "Ready feature", status = "open", issue_type = "feature" },
        { id = "bd-5", title = "In-progress task", status = "in_progress", issue_type = "task" },
    }

    local ready_issues = {
        { id = "bd-4", title = "Ready feature", status = "open", issue_type = "feature" },
    }

    before_each(function()
        -- Mock vim.system
        original_vim_system = vim.system
        vim.system = function(cmd, _, callback)
            local stdout = ""
            if cmd[2] == "list" then
                stdout = vim.json.encode(sample_issues)
            elseif cmd[2] == "ready" then
                stdout = vim.json.encode(ready_issues)
            end
            local result = {
                code = 0,
                stdout = stdout,
                stderr = "",
            }
            if callback then
                callback(result)
            else
                return {
                    wait = function()
                        return result
                    end,
                }
            end
        end

        -- Mock telescope modules
        telescope_finders = {
            new_table = function(params)
                return params
            end,
        }

        telescope_picker = {
            new = function(_, params)
                return {
                    find = function()
                        -- This is where we can assert the results
                        assert.is_not_nil(params.finder, "Finder was not created")
                        assert.is_not_nil(params.finder.results, "Finder has no results")
                        _G.test_results = params.finder.results
                    end,
                }
            end,
        }

        package.loaded["telescope.pickers"] = telescope_picker
        package.loaded["telescope.finders"] = telescope_finders
        package.loaded["telescope.config"] = { values = { generic_sorter = function() end } }
        package.loaded["telescope.actions"] = { select_default = { replace = function() end } }
        package.loaded["telescope.actions.state"] = { get_selected_entry = function() end }
        package.loaded["telescope.previewers"] = {
            new_buffer_previewer = function()
                return {}
            end,
        }
        package.loaded["nvim-beads.issue.formatter"] = { format_issue_to_markdown = function() end }
        package.loaded["nvim-beads.buffer"] = { open_issue_buffer = function() end }

        -- Register the extension
        package.loaded["telescope"] = {
            register_extension = function(ext)
                extension = ext
                return ext
            end,
        }

        -- Clear require cache to reload our extension
        package.loaded["telescope._extensions.nvim_beads"] = nil
        require("telescope._extensions.nvim_beads")
    end)

    after_each(function()
        vim.system = original_vim_system
        _G.test_results = nil
    end)

    it("should register with telescope", function()
        assert.is_not_nil(extension, "Extension should be registered")
    end)

    describe("list function", function()
        it("should show all issues with no filters", function()
            extension.exports.list({})
            assert.equals(#sample_issues, #_G.test_results)
        end)

        it("should filter by status 'open'", function()
            extension.exports.list({ status = "open" })
            assert.equals(3, #_G.test_results) -- bd-1, bd-3, bd-4
            for _, issue in ipairs(_G.test_results) do
                assert.equals("open", issue.status)
            end
        end)

        it("should filter by type 'bug'", function()
            extension.exports.list({ type = "bug" })
            assert.equals(2, #_G.test_results) -- bd-1, bd-2
            for _, issue in ipairs(_G.test_results) do
                assert.equals("bug", issue.issue_type)
            end
        end)

        it("should filter by status 'closed' and type 'bug'", function()
            extension.exports.list({ status = "closed", type = "bug" })
            assert.equals(1, #_G.test_results)
            assert.equals("bd-2", _G.test_results[1].id)
        end)

        it("should use 'bd ready' when status is 'ready'", function()
            local cmd_used
            vim.system = function(cmd, _)
                cmd_used = cmd
                return {
                    wait = function()
                        return { code = 0, stdout = vim.json.encode(ready_issues) }
                    end,
                }
            end
            extension.exports.list({ status = "ready" })
            assert.same({ "bd", "ready", "--json" }, cmd_used)
            assert.equals(#ready_issues, #_G.test_results)
        end)

        it("should filter by type on top of 'ready' status", function()
            local issues_from_ready = {
                { id = "bd-4", title = "Ready feature", status = "open", issue_type = "feature" },
                { id = "bd-6", title = "Ready bug", status = "open", issue_type = "bug" },
            }
            vim.system = function(_, _)
                return {
                    wait = function()
                        return { code = 0, stdout = vim.json.encode(issues_from_ready) }
                    end,
                }
            end

            extension.exports.list({ status = "ready", type = "feature" })
            assert.equals(1, #_G.test_results)
            assert.equals("bd-4", _G.test_results[1].id)
        end)

        it("should handle 'all' for status", function()
            extension.exports.list({ status = "all", type = "feature" })
            assert.equals(2, #_G.test_results) -- bd-3, bd-4
        end)

        it("should handle 'all' for type", function()
            extension.exports.list({ status = "open", type = "all" })
            assert.equals(3, #_G.test_results) -- bd-1, bd-3, bd-4
        end)
    end)

    describe("previewer", function()
        it("should create a buffer previewer", function()
            local previewer_created = false
            package.loaded["telescope.previewers"] = {
                new_buffer_previewer = function(opts)
                    previewer_created = true
                    assert.is_not_nil(opts.define_preview)
                    assert.equals("Issue Preview", opts.title)
                    return opts
                end,
            }

            -- Reload extension to pick up new mock
            package.loaded["telescope._extensions.nvim_beads"] = nil
            require("telescope._extensions.nvim_beads")

            -- Trigger list to create the previewer
            extension.exports.list({})

            assert.is_true(previewer_created)
        end)

        it("should have define_preview function in previewer", function()
            local define_preview_func = nil

            package.loaded["telescope.previewers"] = {
                new_buffer_previewer = function(opts)
                    define_preview_func = opts.define_preview
                    return opts
                end,
            }

            -- Reload extension
            package.loaded["telescope._extensions.nvim_beads"] = nil
            require("telescope._extensions.nvim_beads")
            extension.exports.list({})

            -- Verify the previewer has a define_preview function
            assert.is_not_nil(define_preview_func)
            assert.equals("function", type(define_preview_func))
        end)
    end)

    describe("action mappings", function()
        local actions_mock
        local action_state_mock
        local attach_mappings_func

        before_each(function()
            local select_default_obj = {}
            function select_default_obj:replace(fn)
                _G.test_select_action = fn
            end

            actions_mock = {
                close = function() end,
                select_default = select_default_obj,
            }

            action_state_mock = {
                get_selected_entry = function()
                    return {
                        value = { id = "bd-test", title = "Test issue" },
                    }
                end,
            }

            package.loaded["telescope.actions"] = actions_mock
            package.loaded["telescope.actions.state"] = action_state_mock

            -- Capture attach_mappings function
            telescope_picker.new = function(_, params)
                attach_mappings_func = params.attach_mappings
                return {
                    find = function()
                        if params.finder and params.finder.results then
                            _G.test_results = params.finder.results
                        end
                    end,
                }
            end

            -- Reload extension
            package.loaded["telescope._extensions.nvim_beads"] = nil
            require("telescope._extensions.nvim_beads")
        end)

        it("should map default action to open issue buffer", function()
            -- Mock beads.show BEFORE calling list
            local show_called = false
            local show_id = nil
            package.loaded["nvim-beads"] = {
                show = function(id)
                    show_called = true
                    show_id = id
                end,
                execute = function()
                    return sample_issues
                end,
            }

            -- Reload extension with mock in place
            package.loaded["telescope._extensions.nvim_beads"] = nil
            require("telescope._extensions.nvim_beads")

            extension.exports.list({})
            assert.is_not_nil(attach_mappings_func)

            local prompt_bufnr = vim.api.nvim_create_buf(false, true)

            local map = function(mode, key, fn) -- luacheck: ignore
                -- Mapping function stub for testing
            end

            attach_mappings_func(prompt_bufnr, map)

            -- Verify select_default was replaced
            assert.is_not_nil(_G.test_select_action)
            assert.equals("function", type(_G.test_select_action))

            -- Call the select action
            _G.test_select_action()

            assert.is_true(show_called)
            assert.equals("bd-test", show_id)

            vim.api.nvim_buf_delete(prompt_bufnr, { force = true })
        end)

        it("should map 'd' to delete issue", function()
            extension.exports.list({})
            local prompt_bufnr = vim.api.nvim_create_buf(false, true)
            local map_calls = {}

            local map = function(mode, key, fn)
                map_calls[mode .. ":" .. key] = fn
            end

            attach_mappings_func(prompt_bufnr, map)

            -- Verify 'd' mapping exists
            assert.is_not_nil(map_calls["n:d"])

            vim.api.nvim_buf_delete(prompt_bufnr, { force = true })
        end)

        it("should map 'c' to close issue", function()
            extension.exports.list({})
            local prompt_bufnr = vim.api.nvim_create_buf(false, true)
            local map_calls = {}

            local map = function(mode, key, fn)
                map_calls[mode .. ":" .. key] = fn
            end

            attach_mappings_func(prompt_bufnr, map)

            -- Verify 'c' mapping exists
            assert.is_not_nil(map_calls["n:c"])

            vim.api.nvim_buf_delete(prompt_bufnr, { force = true })
        end)

        it("should map 'o' to open issue", function()
            extension.exports.list({})
            local prompt_bufnr = vim.api.nvim_create_buf(false, true)
            local map_calls = {}

            local map = function(mode, key, fn)
                map_calls[mode .. ":" .. key] = fn
            end

            attach_mappings_func(prompt_bufnr, map)

            -- Verify 'o' mapping exists
            assert.is_not_nil(map_calls["n:o"])

            vim.api.nvim_buf_delete(prompt_bufnr, { force = true })
        end)

        it("should map 'i' to mark issue as in_progress", function()
            extension.exports.list({})
            local prompt_bufnr = vim.api.nvim_create_buf(false, true)
            local map_calls = {}

            local map = function(mode, key, fn)
                map_calls[mode .. ":" .. key] = fn
            end

            attach_mappings_func(prompt_bufnr, map)

            -- Verify 'i' mapping exists
            assert.is_not_nil(map_calls["n:i"])

            vim.api.nvim_buf_delete(prompt_bufnr, { force = true })
        end)
    end)

    describe("entry_maker", function()
        it("should create proper entries from issues", function()
            -- We don't directly expose entry_maker, but we can verify the finder results
            -- are structured correctly
            extension.exports.list({})

            -- test_results should contain the sample issues
            assert.is_not_nil(_G.test_results)
            assert.equals(#sample_issues, #_G.test_results)

            -- Each result should be the original issue object
            for i, result in ipairs(_G.test_results) do
                assert.equals(sample_issues[i].id, result.id)
                assert.equals(sample_issues[i].title, result.title)
            end
        end)
    end)
end)
