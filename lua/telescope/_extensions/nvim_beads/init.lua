--- Register `nvim_beads` to telescope.nvim
---
---@source https://github.com/nvim-telescope/telescope.nvim

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
    error("nvim-beads telescope extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

--- Run the `:Telescope nvim_beads ready` command to show ready issues
---
---@param opts telescope.CommandOptions The Telescope UI / layout options
---
local function ready(opts)
    -- TODO: Implement telescope picker for ready issues
    vim.notify("nvim-beads: Telescope ready picker not yet implemented", vim.log.levels.INFO)
end

--- Run the `:Telescope nvim_beads list` command to show all issues
---
---@param opts telescope.CommandOptions The Telescope UI / layout options
---
local function list(opts)
    opts = opts or {}

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

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

    pickers.new(opts, {
        prompt_title = "Beads Issues",
        finder = finders.new_table({
            results = issues,
            entry_maker = entry_maker,
        }),
        sorter = conf.generic_sorter(opts),
    }):find()
end

return telescope.register_extension({
    exports = {
        ready = ready,
        list = list,
        nvim_beads = list, -- Default action
    },
})
