--- Command parsing and execution for :Beads command

local M = {}

--- Subcommand definitions
---@class Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, Subcommand>
local subcommands = {
    list = {
        impl = function(args)
            require("nvim-beads.core").show_list(args)
        end,
    },
    create = {
        impl = function(args)
            require("nvim-beads.core").create_issue(args)
        end,
    },
    open = {
        impl = function(args)
            require("nvim-beads.buffer").open_issue_buffer(args[1])
        end,
    },
}

--- Execute a :Beads subcommand
---@param opts table Command options from nvim_create_user_command
function M.execute(opts)
    local fargs = opts.fargs

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
---@return string[] List of completion candidates
function M.complete(arg_lead, cmdline)
    -- Parse subcommand and its arguments
    local subcmd, subcmd_arg_lead = cmdline:match("^['<,'>]*Beads[!]*%s+(%S+)%s+(.*)$")

    -- If we have a subcommand with completion function, use it
    if subcmd and subcommands[subcmd] and subcommands[subcmd].complete then
        return subcommands[subcmd].complete(subcmd_arg_lead)
    end

    -- Otherwise, complete subcommand names
    if cmdline:match("^['<,'>]*Beads[!]*%s+%w*$") then
        return vim.tbl_filter(function(key)
            return key:find(arg_lead) ~= nil
        end, vim.tbl_keys(subcommands))
    end

    return {}
end

return M
