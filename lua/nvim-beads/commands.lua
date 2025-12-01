--- Command parsing and execution for :Beads command

local M = {}

--- Subcommand definitions
---@class Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, Subcommand>
local subcommands = {
    ready = {
        impl = function(args, opts)
            require("nvim-beads.core").show_ready()
        end,
    },
    list = {
        impl = function(args, opts)
            require("nvim-beads.core").show_list()
        end,
    },
    create = {
        impl = function(args, opts)
            require("nvim-beads.core").create_issue()
        end,
    },
}

--- Execute a :Beads subcommand
---@param opts table Command options from nvim_create_user_command
function M.execute(opts)
    local fargs = opts.fargs

    if #fargs == 0 then
        vim.notify("nvim-beads: No subcommand provided. Try :Beads ready", vim.log.levels.WARN)
        return
    end

    local subcmd_name = fargs[1]
    local subcmd = subcommands[subcmd_name]

    if not subcmd then
        vim.notify("nvim-beads: Unknown subcommand '" .. subcmd_name .. "'", vim.log.levels.ERROR)
        return
    end

    -- Pass remaining args to the subcommand
    local subcmd_args = vim.list_slice(fargs, 2, #fargs)
    subcmd.impl(subcmd_args, opts)
end

--- Completion for :Beads command
---@param arg_lead string The leading portion of the argument being completed
---@param cmdline string The entire command line
---@param cursor_pos number The cursor position in the command line
---@return string[] List of completion candidates
function M.complete(arg_lead, cmdline, cursor_pos)
    -- Parse subcommand and its arguments
    local subcmd, subcmd_arg_lead = cmdline:match("^['<,'>]*Beads[!]*%s+(%S+)%s+(.*)$")

    -- If we have a subcommand with completion function, use it
    if subcmd and subcommands[subcmd] and subcommands[subcmd].complete then
        return subcommands[subcmd].complete(subcmd_arg_lead)
    end

    -- Otherwise, complete subcommand names
    if cmdline:match("^['<,'>]*Beads[!]*%s+%w*$") then
        return vim.tbl_filter(
            function(key)
                return key:find(arg_lead) ~= nil
            end,
            vim.tbl_keys(subcommands)
        )
    end

    return {}
end

return M
