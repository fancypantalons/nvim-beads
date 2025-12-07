--- Command parsing and execution for :Beads command

local M = {}

--- Create a passthrough command implementation that executes a bd command
--- and displays the output in a scratch buffer
---@param command_name string The bd subcommand to execute
---@return Subcommand
local function passthrough_command(command_name)
    return {
        impl = function(args)
            local util = require("nvim-beads.util")
            util.execute_command_in_scratch_buffer(command_name, args)
        end,
    }
end

--- Subcommand definitions
---@class Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, Subcommand>
local subcommands = {
    list = {
        impl = function(args)
            local beads = require("nvim-beads")
            local constants = require("nvim-beads.constants")

            -- Parse args into opts
            local opts = {}

            for _, arg in ipairs(args) do
                local normalized = constants.PLURAL_MAP[arg:lower()] or arg:lower()

                if constants.STATUSES[normalized] and not opts.status then
                    opts.status = normalized
                elseif constants.ISSUE_TYPES[normalized] and not opts.type then
                    opts.type = normalized
                else
                    vim.notify(
                        string.format("Beads list: invalid or duplicate argument '%s'", arg),
                        vim.log.levels.ERROR
                    )
                    return
                end
            end

            beads.list(opts)
        end,
    },
    ready = {
        impl = function(args)
            local beads = require("nvim-beads")
            local constants = require("nvim-beads.constants")

            -- Parse args into opts (only issue types are valid for ready)
            local opts = {}

            for _, arg in ipairs(args) do
                local normalized = constants.PLURAL_MAP[arg:lower()] or arg:lower()

                if constants.ISSUE_TYPES[normalized] and not opts.type then
                    opts.type = normalized
                else
                    vim.notify(
                        string.format("Beads ready: invalid or duplicate argument '%s'", arg),
                        vim.log.levels.ERROR
                    )
                    return
                end
            end

            beads.ready(opts)
        end,
    },
    create = {
        impl = function(args)
            -- Validate that we have exactly one argument
            if #args == 0 then
                vim.notify("Beads create: missing issue type. Usage: :Beads create <type>", vim.log.levels.ERROR)
                vim.notify("Valid types: bug, feature, task, epic, chore", vim.log.levels.INFO)
                return
            end

            if #args > 1 then
                vim.notify("Beads create: too many arguments. Usage: :Beads create <type>", vim.log.levels.ERROR)
                return
            end

            local beads = require("nvim-beads")
            beads.create({ type = args[1] })
        end,
    },
    open = {
        impl = function(args)
            if #args == 0 then
                vim.notify("Beads open: missing issue ID. Usage: :Beads open <issue-id>", vim.log.levels.ERROR)
                return
            end

            local beads = require("nvim-beads")
            beads.show(args[1])
        end,
    },
    show = {
        impl = function(args)
            if #args == 0 then
                vim.notify("Beads show: missing issue ID. Usage: :Beads show <issue-id>", vim.log.levels.ERROR)
                return
            end

            local beads = require("nvim-beads")
            beads.show(args[1])
        end,
    },
    compact = passthrough_command("compact"),
    cleanup = passthrough_command("cleanup"),
    sync = passthrough_command("sync"),
    daemon = passthrough_command("daemon"),
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
