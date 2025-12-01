--- Entry point for nvim-beads plugin
--- Defines commands and keymaps (deferred loading)

-- Prevent loading the plugin twice
if vim.g.loaded_nvim_beads then
    return
end
vim.g.loaded_nvim_beads = true

-- Create the main Beads command with subcommands (lazy-loaded)
vim.api.nvim_create_user_command("Beads", function(opts)
    require("nvim-beads.commands").execute(opts)
end, {
    nargs = "*",
    desc = "Beads issue tracker integration",
    complete = function(arg_lead, cmdline, cursor_pos)
        return require("nvim-beads.commands").complete(arg_lead, cmdline, cursor_pos)
    end,
})

-- Provide <Plug> mappings for users to bind (lazy-loaded)
vim.keymap.set("n", "<Plug>(BeadsReady)", function()
    require("nvim-beads.core").show_ready()
end, { desc = "Show ready beads issues" })

vim.keymap.set("n", "<Plug>(BeadsList)", function()
    require("nvim-beads.core").show_list()
end, { desc = "List all beads issues" })

vim.keymap.set("n", "<Plug>(BeadsCreate)", function()
    require("nvim-beads.core").create_issue()
end, { desc = "Create a new beads issue" })

-- Direct command to open an issue buffer by ID
vim.api.nvim_create_user_command("BeadsOpenIssue", function(opts)
    require("nvim-beads.issue").open_issue_buffer(opts.args)
end, {
    nargs = 1,
    desc = "Open a beads issue by ID in a buffer",
})

-- Command to create a new issue with template
vim.api.nvim_create_user_command("BeadsCreateIssue", function(opts)
    local args = opts.fargs

    -- Validate that we have exactly one argument
    if #args == 0 then
        vim.notify("BeadsCreateIssue: missing issue type. Usage: :BeadsCreateIssue <type>", vim.log.levels.ERROR)
        vim.notify("Valid types: bug, feature, task, epic, chore", vim.log.levels.INFO)
        return
    end

    if #args > 1 then
        vim.notify("BeadsCreateIssue: too many arguments. Usage: :BeadsCreateIssue <type>", vim.log.levels.ERROR)
        return
    end

    local issue_type = args[1]

    -- Fetch the template
    local core = require("nvim-beads.core")
    local template, err = core.fetch_template(issue_type)

    if err then
        vim.notify("BeadsCreateIssue: " .. err, vim.log.levels.ERROR)
        return
    end

    -- Open new issue buffer with template
    local issue = require("nvim-beads.issue")
    local success = issue.open_new_issue_buffer(issue_type, template)

    if not success then
        vim.notify("BeadsCreateIssue: Failed to create issue buffer", vim.log.levels.ERROR)
    end
end, {
    nargs = "+",
    desc = "Create a new beads issue from template",
    complete = function(arg_lead, cmdline, cursor_pos)
        local valid_types = {"bug", "feature", "task", "epic", "chore"}
        return vim.tbl_filter(function(type)
            return type:find(arg_lead) == 1
        end, valid_types)
    end,
})

-- Setup autocommands for beads:// buffers
require("nvim-beads.autocmds").setup()
