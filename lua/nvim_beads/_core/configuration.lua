--- All functions and data to help customize `nvim_beads` for this user.

local say_constant = require("nvim_beads._commands.hello_world.say.constant")

local logging = require("mega.logging")

local _LOGGER = logging.get_logger("nvim_beads._core.configuration")

local M = {}

-- NOTE: Don't remove this line. It makes the Lua module much easier to reload
vim.g.loaded_nvim_beads = false

---@type nvim_beads.Configuration
M.DATA = {}

---@type nvim_beads.Configuration
local _DEFAULTS = {
    logging = { level = "info", use_console = false, use_file = false },
}

-- TODO: (you) Update these sections depending on your intended plugin features.
local _EXTRA_DEFAULTS = {
    commands = {
        hello_world = {
            say = { ["repeat"] = 1, style = say_constant.Keyword.style.lowercase },
        },
    },
    tools = {
        telescope = {
            hello_world = { "Hi there!", "Hello, Sailor!", "What's up, doc?" },
        },
    },
}

_DEFAULTS = vim.tbl_deep_extend("force", _DEFAULTS, _EXTRA_DEFAULTS)

--- Setup `nvim_beads` for the first time, if needed.
function M.initialize_data_if_needed()
    if vim.g.loaded_nvim_beads then
        return
    end

    M.DATA = vim.tbl_deep_extend("force", _DEFAULTS, vim.g.nvim_beads_configuration or {})

    vim.g.loaded_nvim_beads = true

    local configuration = M.DATA.logging or {}
    ---@cast configuration mega.logging.SparseLoggerOptions
    logging.set_configuration("nvim_beads", configuration)

    _LOGGER:fmt_debug("Initialized nvim-beads's configuration.")
end

--- Merge `data` with the user's current configuration.
---
---@param data nvim_beads.Configuration? All extra customizations for this plugin.
---@return nvim_beads.Configuration # The configuration with 100% filled out values.
---
function M.resolve_data(data)
    M.initialize_data_if_needed()

    return vim.tbl_deep_extend("force", M.DATA, data or {})
end

return M
