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
