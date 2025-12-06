--- Register `nvim_beads` to telescope.nvim
---
---@source https://github.com/nvim-telescope/telescope.nvim

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
    error("nvim-beads telescope extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local beads = require("nvim-beads")

-- Internal modules for formatting only (not core/buffer)
local formatter = require("nvim-beads.issue.formatter")

--- Create a previewer for beads issues
---
---@return table The telescope previewer
---
local function create_issue_previewer()
    return previewers.new_buffer_previewer({
        title = "Issue Preview",
        define_preview = function(self, entry)
            -- Extract issue_id from entry.value
            local issue_id = entry.value.id

            -- Fetch issue asynchronously using public API
            beads.execute({ "show", issue_id }, {
                async = true,
                callback = function(result, err)
                    if err then
                        -- Handle error gracefully
                        local error_lines = {
                            "Error fetching issue details:",
                            "",
                            err,
                        }
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, error_lines)
                        return
                    end

                    -- bd show returns an array with a single issue
                    local issue = nil
                    if type(result) == "table" and #result > 0 then
                        issue = result[1]
                    end

                    if not issue then
                        local error_lines = { "No issue data returned" }
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, error_lines)
                        return
                    end

                    -- Format issue and populate preview buffer
                    local lines = formatter.format_issue_for_buffer(issue)
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                end,
            })
        end,
    })
end

--- Run the `:Telescope nvim_beads list` command to show all issues
---
---@param call_opts table|nil Either Telescope options or a filter table {status?: string, type?: string}
local function list(call_opts)
    local opts, filters
    if call_opts then
        if call_opts.status or call_opts.type or call_opts.priority or call_opts.assignee then
            filters = call_opts
            opts = {}
        else
            opts = call_opts
            filters = {}
        end
    else
        opts = {}
        filters = {}
    end

    -- Choose the bd command based on filters
    local args
    if filters.status == "ready" then
        args = { "ready" }
    elseif filters.status == "stale" then
        args = { "stale" }
    else
        args = { "list" }
    end

    -- Run bd command using public API and parse the output
    local all_issues, err = beads.execute(args)
    if err then
        vim.notify("Failed to list issues: " .. err, vim.log.levels.ERROR)
        return
    end

    -- Filter issues in Lua
    local filtered_issues = {}
    for _, issue in ipairs(all_issues) do
        -- 'ready' is a special status that uses `bd ready`. We don't need to re-filter by status
        -- if the user asked for 'ready' issues.
        local status_match = true
        if filters.status and filters.status ~= "all" and filters.status ~= "ready" and filters.status ~= "stale" then
            status_match = issue.status == filters.status
        end

        local type_match = true
        if filters.type and filters.type ~= "all" then
            type_match = issue.issue_type == filters.type
        end

        -- TODO: Add priority and assignee filtering when supported
        -- local priority_match = true
        -- if filters.priority then
        --     priority_match = issue.priority == filters.priority
        -- end
        --
        -- local assignee_match = true
        -- if filters.assignee then
        --     assignee_match = issue.assignee == filters.assignee
        -- end

        if status_match and type_match then
            table.insert(filtered_issues, issue)
        end
    end

    -- Entry maker function
    local function entry_maker(issue)
        return {
            value = issue,
            display = issue.id .. ": " .. issue.title,
            ordinal = issue.title,
        }
    end

    pickers
        .new(opts, {
            prompt_title = "Beads Issues",
            finder = finders.new_table({
                results = filtered_issues,
                entry_maker = entry_maker,
            }),
            sorter = conf.generic_sorter(opts),
            previewer = create_issue_previewer(),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    beads.show(selection.value.id)
                end)

                local function delete_issue(p_prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        vim.notify("No issue selected", vim.log.levels.WARN)
                        return
                    end

                    local issue_id = selection.value.id
                    if vim.fn.confirm("Delete issue " .. issue_id .. "?", "&Yes\n&No", 2) == 1 then
                        beads.execute({ "delete", issue_id, "--force" }, {
                            async = true,
                            callback = function(_, err)
                                if err then
                                    vim.notify("Failed to delete issue " .. issue_id .. ": " .. err, vim.log.levels.ERROR)
                                else
                                    vim.notify("Issue " .. issue_id .. " deleted")
                                    actions.close(p_prompt_bufnr)
                                    list(call_opts)
                                end
                            end,
                        })
                    end
                end

                local function close_issue(p_prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        vim.notify("No issue selected", vim.log.levels.WARN)
                        return
                    end

                    local issue_id = selection.value.id
                    if vim.fn.confirm("Close issue " .. issue_id .. "?", "&Yes\n&No", 2) == 1 then
                        beads.execute({ "update", issue_id, "--status", "closed" }, {
                            async = true,
                            callback = function(_, err)
                                if err then
                                    vim.notify("Failed to close issue " .. issue_id .. ": " .. err, vim.log.levels.ERROR)
                                else
                                    vim.notify("Issue " .. issue_id .. " closed")
                                    actions.close(p_prompt_bufnr)
                                    list(call_opts)
                                end
                            end,
                        })
                    end
                end

                local function open_issue(p_prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        vim.notify("No issue selected", vim.log.levels.WARN)
                        return
                    end

                    local issue_id = selection.value.id
                    if vim.fn.confirm("Open issue " .. issue_id .. "?", "&Yes\n&No", 2) == 1 then
                        beads.execute({ "update", issue_id, "--status", "open" }, {
                            async = true,
                            callback = function(_, err)
                                if err then
                                    vim.notify("Failed to open issue " .. issue_id .. ": " .. err, vim.log.levels.ERROR)
                                else
                                    vim.notify("Issue " .. issue_id .. " opened")
                                    actions.close(p_prompt_bufnr)
                                    list(call_opts)
                                end
                            end,
                        })
                    end
                end

                local function mark_as_in_progress(p_prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        vim.notify("No issue selected", vim.log.levels.WARN)
                        return
                    end

                    local issue_id = selection.value.id
                    if vim.fn.confirm("Mark issue " .. issue_id .. " as in-progress?", "&Yes\n&No", 2) == 1 then
                        beads.execute({ "update", issue_id, "--status", "in_progress" }, {
                            async = true,
                            callback = function(_, err)
                                if err then
                                    vim.notify("Failed to mark issue " .. issue_id .. " as in-progress: " .. err, vim.log.levels.ERROR)
                                else
                                    vim.notify("Issue " .. issue_id .. " marked as in-progress")
                                    actions.close(p_prompt_bufnr)
                                    list(call_opts)
                                end
                            end,
                        })
                    end
                end

                map("n", "d", delete_issue)
                map("n", "c", close_issue)
                map("n", "o", open_issue)
                map("n", "i", mark_as_in_progress)

                return true
            end,
        })
        :find()
end

return telescope.register_extension({
    exports = {
        list = list,
        nvim_beads = list, -- Default action
    },
})
