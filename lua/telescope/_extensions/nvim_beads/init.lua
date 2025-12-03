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
local formatter = require("nvim-beads.issue.formatter")
local buffer = require("nvim-beads.buffer")

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

            -- Call bd show --json asynchronously
            vim.system({ "bd", "show", "--json", issue_id }, { text = true }, function(result)
                -- Schedule UI update for main thread
                vim.schedule(function()
                    if result.code ~= 0 then
                        -- Handle error gracefully
                        local error_lines = {
                            "Error fetching issue details:",
                            "",
                            result.stderr or "Unknown error",
                        }
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, error_lines)
                        return
                    end

                    -- Parse JSON response (bd show returns an array with a single issue)
                    local ok, issues = pcall(vim.json.decode, result.stdout)
                    if not ok or not issues or type(issues) ~= "table" or #issues == 0 then
                        local error_lines = {
                            "Error parsing issue JSON:",
                            "",
                            "Failed to decode bd show output",
                        }
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, error_lines)
                        return
                    end

                    -- Extract the first (and only) issue from the array
                    local issue = issues[1]

                    -- Format issue to markdown
                    local lines = formatter.format_issue_to_markdown(issue)

                    -- Split any lines that contain newlines (nvim_buf_set_lines doesn't accept embedded newlines)
                    local flattened_lines = {}
                    for _, line in ipairs(lines) do
                        if line:find("\n") then
                            -- Split on newlines, preserving blank lines
                            local pos = 1
                            while pos <= #line do
                                local next_newline = line:find("\n", pos, true)
                                if next_newline then
                                    table.insert(flattened_lines, line:sub(pos, next_newline - 1))
                                    pos = next_newline + 1
                                else
                                    table.insert(flattened_lines, line:sub(pos))
                                    break
                                end
                            end
                        else
                            table.insert(flattened_lines, line)
                        end
                    end

                    -- Write lines to preview buffer
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, flattened_lines)

                    -- Set filetype to markdown for syntax highlighting
                    vim.api.nvim_set_option_value("filetype", "markdown", { buf = self.state.bufnr })
                end)
            end)
        end,
    })
end

--- Run the `:Telescope nvim_beads list` command to show all issues
---
---@param call_opts table|nil Either Telescope options or a filter table {state?: string, type?: string}
local function list(call_opts)
    local opts, filters
    if call_opts then
        if call_opts.state or call_opts.type then
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
    local cmd
    if filters.state == "ready" then
        cmd = { "bd", "ready", "--json" }
    else
        cmd = { "bd", "list", "--json" }
    end

    -- Run bd command and parse the output
    local result = vim.system(cmd, { text = true }):wait()

    if result.code ~= 0 then
        vim.notify("Failed to run '" .. table.concat(cmd, " ") .. "': " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
    end

    -- Parse JSON array
    local ok, all_issues = pcall(vim.json.decode, result.stdout)
    if not ok or not all_issues then
        vim.notify("Failed to parse JSON output from '" .. table.concat(cmd, " ") .. "'", vim.log.levels.ERROR)
        return
    end

    -- Filter issues in Lua
    local filtered_issues = {}
    for _, issue in ipairs(all_issues) do
        -- 'ready' is a special state that uses `bd ready`. We don't need to re-filter by status
        -- if the user asked for 'ready' issues.
        local state_match = true
        if filters.state and filters.state ~= "all" and filters.state ~= "ready" then
            state_match = issue.status == filters.state
        end

        local type_match = true
        if filters.type and filters.type ~= "all" then
            type_match = issue.issue_type == filters.type
        end

        if state_match and type_match then
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
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    buffer.open_issue_buffer(selection.value.id)
                end)
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
