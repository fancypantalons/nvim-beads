--- A collection of types to be included / used in other Lua files.
---
--- These types are either required by the Lua API or required for the normal
--- operation of this Lua plugin.
---

---@class nvim_beads.Configuration
---    The user's customizations for this plugin.
---@field commands nvim_beads.ConfigurationCommands?
---    Customize the fallback behavior of all `:YourPlugin` commands.
---@field logging nvim_beads.LoggingConfiguration?
---    Control how and which logs print to file / Neovim.
---@field tools nvim_beads.ConfigurationTools?
---    Optional third-party tool integrations.

---@class nvim_beads.ConfigurationCommands
---    Customize the fallback behavior of all `:YourPlugin` commands.
---@field goodnight_moon nvim_beads.ConfigurationGoodnightMoon?
---    The default values when a user calls `:YourPlugin goodnight-moon`.
---@field hello_world nvim_beads.ConfigurationHelloWorld?
---    The default values when a user calls `:YourPlugin hello-world`.

---@class nvim_beads.ConfigurationGoodnightMoon
---    The default values when a user calls `:YourPlugin goodnight-moon`.
---@field read nvim_beads.ConfigurationGoodnightMoonRead?
---    The default values when a user calls `:YourPlugin goodnight-moon read`.

---@class nvim_beads.LoggingConfiguration
---    Control whether or not logging is printed to the console or to disk.
---@field level (
---    | "trace"
---    | "debug"
---    | "info"
---    | "warn" | "error"
---    | "fatal"
---    | vim.log.levels.DEBUG
---    | vim.log.levels.ERROR
---    | vim.log.levels.INFO
---    | vim.log.levels.TRACE
---    | vim.log.levels.WARN)?
---    Any messages above this level will be logged.
---@field use_console boolean?
---    Should print the output to neovim while running. Warning: This is very
---    spammy. You probably don't want to enable this unless you have to.
---@field use_file boolean?
---    Should write to a file.
---@field output_path string?
---    The default path on-disk where log files will be written to.
---    Defaults to "/home/selecaoone/.local/share/nvim/plugin_name.log".

---@class nvim_beads.ConfigurationGoodnightMoonRead
---    The default values when a user calls `:YourPlugin goodnight-moon read`.
---@field phrase string
---    The book to read if no book is given by the user.

---@class nvim_beads.ConfigurationHelloWorld
---    The default values when a user calls `:YourPlugin hello-world`.
---@field say nvim_beads.ConfigurationHelloWorldSay?
---    The default values when a user calls `:YourPlugin hello-world say`.

---@class nvim_beads.ConfigurationHelloWorldSay
---    The default values when a user calls `:YourPlugin hello-world say`.
---@field repeat number
---    A 1-or-more value. When 1, the phrase is said once. When 2+, the phrase
---    is repeated that many times.
---@field style "lowercase" | "uppercase"
---    Control how the text is displayed. e.g. "uppercase" changes "hello" to "HELLO".

---@class nvim_beads.ConfigurationTools
---    Optional third-party tool integrations.
---@field lualine nvim_beads.ConfigurationToolsLualine?
---    A Vim statusline replacement that will show the command that the user just ran.

---@alias nvim_beads.ConfigurationToolsLualine table<string, plugin_template.ConfigurationToolsLualineData>
---    Each runnable command and its display text.

---@class nvim_beads.ConfigurationToolsLualineData
---    The display values that will be used when a specific `nvim_beads`
---    command runs.
---@diagnostic disable-next-line: undefined-doc-name
---@field color vim.api.keyset.highlight?
---    The foreground/background color to use for the Lualine status.
---@field prefix string?
---    The text to display in lualine.
