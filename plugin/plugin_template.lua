--- All `nvim_beads` command definitions.

local cmdparse = require("mega.cmdparse")

local _PREFIX = "YourPlugin"

---@type mega.cmdparse.ParserCreator
local _SUBCOMMANDS = function()
    local arbitrary_thing = require("nvim_beads._commands.arbitrary_thing.parser")
    local copy_logs = require("nvim_beads._commands.copy_logs.parser")
    local goodnight_moon = require("nvim_beads._commands.goodnight_moon.parser")
    local hello_world = require("nvim_beads._commands.hello_world.parser")

    local parser = cmdparse.ParameterParser.new({ name = _PREFIX, help = "The root of all commands." })
    local subparsers = parser:add_subparsers({ "commands", help = "All runnable commands." })

    subparsers:add_parser(arbitrary_thing.make_parser())
    subparsers:add_parser(copy_logs.make_parser())
    subparsers:add_parser(goodnight_moon.make_parser())
    subparsers:add_parser(hello_world.make_parser())

    return parser
end

cmdparse.create_user_command(_SUBCOMMANDS, _PREFIX)

vim.keymap.set("n", "<Plug>(YourPluginSayHi)", function()
    local configuration = require("nvim_beads._core.configuration")
    local nvim_beads = require("plugin_template")

    configuration.initialize_data_if_needed()

    nvim_beads.run_hello_world_say_word("Hi!")
end, { desc = "Say hi to the user." })
