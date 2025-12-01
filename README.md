# nvim-beads

A Neovim plugin for integrating with the [beads (bd)](https://github.com/steveyegge/beads) issue tracker.

| <!-- --> | <!-- --> |
|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/YourUsername/nvim-beads.nvim/test.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/test.yml) [![documentation](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/documentation.yml?branch=main&style=for-the-badge&label=Documentation)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/documentation.yml) [![luacheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/luacheck.yml) [![llscheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/llscheck.yml?branch=main&style=for-the-badge&label=llscheck)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/llscheck.yml) [![checkhealth](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/checkhealth.yml?branch=main&style=for-the-badge&label=checkhealth)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/checkhealth.yml) [![stylua](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/stylua.yml?branch=main&style=for-the-badge&label=Stylua)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/stylua.yml) [![urlchecker](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/urlchecker.yml?branch=main&style=for-the-badge&label=URLChecker)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/urlchecker.yml) [![mdformat](https://img.shields.io/github/actions/workflow/status/ColinKennedy/nvim-beads.nvim/mdformat.yml?branch=main&style=for-the-badge&label=mdformat)](https://github.com/ColinKennedy/nvim-beads.nvim/actions/workflows/mdformat.yml) |
| License | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/YourUsername/nvim-beads.nvim/blob/main/LICENSE) |
| Social | [![RSS](https://img.shields.io/badge/rss-F88900?style=for-the-badge&logo=rss&logoColor=white)](https://github.com/YourUsername/nvim-beads.nvim/commits/main/doc/news.txt.atom) |

# Features

- View ready (unblocked) beads issues directly in Neovim
- Browse all issues with Telescope integration
- Create new issues from within Neovim
- Fast startup with lazy-loaded modules
- Follows Neovim plugin best practices
- 100% Lua
- [LuaCATS](https://luals.github.io/wiki/annotations/) type annotations

# Installation

<!-- TODO: (you) - Adjust and add your dependencies as needed here -->

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "brettk/nvim-beads",
    dependencies = {
        "nvim-telescope/telescope.nvim", -- Optional, for Telescope integration
    },
    cmd = "Beads",
    keys = {
        { "<leader>br", "<Plug>(BeadsReady)", desc = "Show ready beads issues" },
        { "<leader>bl", "<Plug>(BeadsList)", desc = "List all beads issues" },
        { "<leader>bc", "<Plug>(BeadsCreate)", desc = "Create beads issue" },
    },
}
```

# Configuration

(These are default values)

<!-- TODO: (you) - Remove / Add / Adjust your configuration here -->

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "YourUsername/nvim-beads.nvim",
    config = function()
        vim.g.nvim_beads_configuration = {
            commands = {
                goodnight_moon = { read = { phrase = "A good book" } },
                hello_world = {
                    say = { ["repeat"] = 1, style = "lowercase" },
                },
            },
            logging = {
                level = "info",
                use_console = false,
                use_file = false,
            },
            tools = {
                lualine = {
                    arbitrary_thing = {
                        color = "Visual",
                        text = " Arbitrary Thing",
                    },
                    copy_logs = {
                        color = "Comment",
                        text = "󰈔 Copy Logs",
                    },
                    goodnight_moon = {
                        color = "Question",
                        text = " Goodnight moon",
                    },
                    hello_world = {
                        color = "Title",
                        text = " Hello, World!",
                    },
                },
                telescope = {
                    goodnight_moon = {
                        { "Foo Book", "Author A" },
                        { "Bar Book Title", "John Doe" },
                        { "Fizz Drink", "Some Name" },
                        { "Buzz Bee", "Cool Person" },
                    },
                    hello_world = { "Hi there!", "Hello, Sailor!", "What's up, doc?" },
                },
            },
        }
    end
}
```

## Lualine

<!-- TODO: (you) - Remove this is you do not want lualine -->

> Note: You can customize lualine colors here or using
> `vim.g.nvim_beads_configuration`.

[lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)

```lua
require("lualine").setup {
    sections = {
        lualine_y = {
            -- ... Your other configuration ...
            {
                "nvim_beads",
                -- NOTE: These will override default values
                -- display = {
                --     goodnight_moon = {color={fg="#FFFFFF"}, text="Custom message 1"}},
                --     hello_world = {color={fg="#333333"}, text="Custom message 2"},
                -- },
            },
        }
    }
}
```

## Telescope

<!-- TODO: (you) - Remove this is you do not want telescope -->

> Note: You can customize telescope colors here or using
> `vim.g.nvim_beads_configuration`.

[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

```lua
{
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    config = function()
        -- ... Your other configuration ...
        require("telescope").load_extension("nvim_beads")
    end,
    dependencies = {
        "YourUsername/nvim-beads.nvim",
        "nvim-lua/plenary.nvim",
    },
    version = "0.1.*",
},
```

### Colors

This plugin provides two default highlights

- `YourPluginTelescopeEntry`
- `YourPluginTelescopeSecondary`

Both come with default colors that should look nice. If you want to change them, here's how:

```lua
vim.api.nvim_set_hl(0, "YourPluginTelescopeEntry", {link="Statement"})
vim.api.nvim_set_hl(0, "YourPluginTelescopeSecondary", {link="Question"})
```

# Usage

## Commands

```vim
:Beads ready    " Show ready (unblocked) issues
:Beads list     " List all issues
:Beads create   " Create a new issue
```

## Keymaps

The plugin provides `<Plug>` mappings you can bind to your preferred keys:

```lua
vim.keymap.set("n", "<leader>br", "<Plug>(BeadsReady)")
vim.keymap.set("n", "<leader>bl", "<Plug>(BeadsList)")
vim.keymap.set("n", "<leader>bc", "<Plug>(BeadsCreate)")
```

## Telescope Integration

If you have telescope.nvim installed:

```vim
:Telescope nvim_beads ready
:Telescope nvim_beads list
```

# Tests

## Initialization

Run this line once before calling any `busted` command

```sh
eval $(luarocks path --lua-version 5.1 --bin)
```

## Running

Run all tests

```sh
# Using the package manager
luarocks test --test-type busted
# Or manually
busted .
# Or with Make
make test
```

Run test based on tags

```sh
busted . --tags=simple
```

# Coverage

Making sure that your plugin is well tested is important.
`nvim-beads.nvim` can generate a per-line breakdown of exactly where
your code is lacking tests using [LuaCov](https://luarocks.org/modules/mpeterv/luacov).

## Setup

Make sure to install all dependencies for the unittests + coverage reporter if
you have not installed them already.

```sh
luarocks install busted --local
luarocks install luacov --local
luarocks install luacov-multiple --local
```

## Running

```sh
make coverage-html
```

This will generate a `luacov.stats.out` & `luacov_html/` directory.

## Viewing

```sh
(cd luacov_html && python -m http.server)
```

If it worked, you should see a message like
`"Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000) ..."`
Open `http://0.0.0.0:8000` in a browser like
[Firefox](https://www.mozilla.org/en-US/firefox) and you should see a view like this:

![Image](https://github.com/user-attachments/assets/e5b30df8-036a-4886-81b9-affbf5c9e32a)

Just navigate down a few folders until you get to a .lua file and you'll see a breakdown
of your line coverage like this:

![Image](https://github.com/user-attachments/assets/c5420b16-4be7-4177-92c7-01af0b418816)

# Tracking Updates

See [doc/news.txt](doc/news.txt) for updates.

You can watch this plugin for changes by adding this URL to your RSS feed:

```
https://github.com/YourUsername/nvim-beads.nvim/commits/main/doc/news.txt.atom
```

# Other Plugins

This template is full of various features. But if your plugin is only meant to
be a simple plugin and you don't want the bells and whistles that this template
provides, consider instead using
[nvim-nvim-beads](https://github.com/ellisonleao/nvim-plugin-template)
