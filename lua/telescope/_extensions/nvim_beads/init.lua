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
    -- TODO: Implement telescope picker for all issues
    vim.notify("nvim-beads: Telescope list picker not yet implemented", vim.log.levels.INFO)
end

return telescope.register_extension({
    exports = {
        ready = ready,
        list = list,
        nvim_beads = list, -- Default action
    },
})
