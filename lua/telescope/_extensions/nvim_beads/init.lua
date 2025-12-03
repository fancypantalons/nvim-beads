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
local issue_module = require("nvim-beads.issue")

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
                    local lines = issue_module.format_issue_to_markdown(issue)

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
---@param opts telescope.CommandOptions The Telescope UI / layout options
---
local function list(opts)
    opts = opts or {}

    -- Run bd list --json and parse the output
    local result = vim.system({ "bd", "list", "--json" }, { text = true }):wait()

    if result.code ~= 0 then
        vim.notify("Failed to run 'bd list --json': " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
    end

    -- Parse JSON array
    local ok, issues = pcall(vim.json.decode, result.stdout)
    if not ok or not issues then
        vim.notify("Failed to parse JSON output from 'bd list --json'", vim.log.levels.ERROR)
        return
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
                results = issues,
                entry_maker = entry_maker,
            }),
            sorter = conf.generic_sorter(opts),
            previewer = create_issue_previewer(),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    issue_module.open_issue_buffer(selection.value.id)
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
