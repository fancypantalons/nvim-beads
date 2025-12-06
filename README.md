# nvim-beads

A Neovim plugin for integrating with [bd (beads)](https://github.com/steveyegge/beads)--a lightweight, git-friendly issue tracker.

| <!-- --> | <!-- --> |
|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/test.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/brettk/nvim-beads/actions/workflows/test.yml) [![documentation](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/documentation.yml?branch=main&style=for-the-badge&label=Documentation)](https://github.com/brettk/nvim-beads/actions/workflows/documentation.yml) [![luacheck](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/brettk/nvim-beads/actions/workflows/luacheck.yml) [![checkhealth](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/checkhealth.yml?branch=main&style=for-the-badge&label=checkhealth)](https://github.com/brettk/nvim-beads/actions/workflows/checkhealth.yml) [![stylua](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/stylua.yml?branch=main&style=for-the-badge&label=Stylua)](https://github.com/brettk/nvim-beads/actions/workflows/stylua.yml) [![urlchecker](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/urlchecker.yml?branch=main&style=for-the-badge&label=URLChecker)](https://github.com/brettk/nvim-beads/actions/workflows/urlchecker.yml) [![mdformat](https://img.shields.io/github/actions/workflow/status/brettk/nvim-beads/mdformat.yml?branch=main&style=for-the-badge&label=mdformat)](https://github.com/brettk/nvim-beads/actions/workflows/mdformat.yml) |
| License | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/brettk/nvim-beads/blob/main/LICENSE) |
| Social | [![RSS](https://img.shields.io/badge/rss-F88900?style=for-the-badge&logo=rss&logoColor=white)](https://github.com/brettk/nvim-beads/commits/main/doc/news.txt.atom) |

## What is this?

[Beads](https://github.com/steveyegge/beads) is described by the author as:

> Beads is a lightweight memory system for coding agents, using a graph-based issue tracker. Four kinds of dependencies work to chain your issues together like beads, making them easy for agents to follow for long distances, and reliably perform complex task streams in the right order.

In practice, Beads is essentially a ticketing system where the data resides right in your code repository. For people who don't want to be tied down to centralized infrastructure, this is nice as it divorces your issue tracking from the platform where your code is hosted. For LLMs, this is enormously powerful as the full ticketing system is local and available and can be used for long-term memory, context control, and as an alternative to to-do-lists or similar mechanisms.

But, Beads is a command-line tool, and as a command-line tool, can be a bit difficult to work with as a human, and that's where this plugin comes in. `nvim-beads` allows you list, create, edit, and close Beads tickets right from Neovim.

## Features

- Browse and filter issues using Telescope
- View ready/unblocked issues so you know what to work on next
- Create new issues without leaving your editor
- Edit issue details in markdown-formatted buffers
- Filter by status, type, priority, assignee using natural language
- Fast lazy-loading
- Clean Lua API for scripting [bd (beads)](https://github.com/steveyegge/beads) command-line tool
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required, not optional)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "brettk/nvim-beads",
    dependencies = {
        "nvim-telescope/telescope.nvim", -- Required
    },
    cmd = "Beads",
}
```

## Quick Start

Initialize bd in your project (if you haven't already):

```bash
cd /path/to/your/project
bd init
```

Then from Neovim:

```vim
" Browse issues
:Beads list                 " All open issues
:Beads list ready           " Ready (unblocked) issues
:Beads list bugs            " All bugs
:Beads list open features   " Open features

" View/edit a specific issue
:Beads show bd-123

" Create a new issue
:Beads create bug
```

## Usage

### Commands

#### `:Beads list [status] [type]`

Browse and filter issues using natural language. Arguments are positional but flexible--the parser figures out whether you're specifying a status or type.

**Valid statuses:** `open`, `in_progress`, `blocked`, `closed`, `ready`, `stale`, `all`

**Valid types:** `bug`/`bugs`, `feature`/`features`, `task`/`tasks`, `epic`/`epics`, `chore`/`chores`, `all`

Examples:

```vim
:Beads list                " All open issues (default)
:Beads list ready          " Ready (unblocked) issues
:Beads list bugs           " All bugs
:Beads list open bugs      " Open bugs
:Beads list ready features " Ready features
```

#### `:Beads create {type}`

Create a new issue. Opens a markdown buffer with a template--fill it in and save.

Valid types: `bug`, `feature`, `task`, `epic`, `chore`

```vim
:Beads create bug
:Beads create feature
```

#### `:Beads show {issue-id}`

Open a specific issue by ID. Edit the markdown buffer and save to update the issue.

```vim
:Beads show bd-123
```

#### Other commands

- `:Beads compact` - Compact the issues database
- `:Beads cleanup` - Clean up orphaned dependencies
- `:Beads sync` - Sync issues with git
- `:Beads daemon` - Start the bd daemon

### Telescope Integration

The `:Beads list` command is just a convenience wrapper. You can also call Telescope directly:

```vim
:Telescope nvim_beads list
:Telescope nvim_beads list status=ready
:Telescope nvim_beads list type=bug
```

Or via Lua:

```lua
local telescope = require("telescope")
telescope.load_extension("nvim_beads")

telescope.extensions.nvim_beads.list()
telescope.extensions.nvim_beads.list({ status = "ready", type = "bug" })
```

**Telescope keymaps** (while browsing issues):

- `<CR>` - Open the issue
- `d` - Delete the issue (with confirmation)
- `c` - Mark as closed
- `o` - Reopen
- `i` - Mark as in-progress

### Lua API

The plugin provides a public Lua API if you want to integrate it into your own scripts:

```lua
local beads = require("nvim-beads")

-- List issues with filters
beads.list({ status = "ready", type = "bug" })

-- Show a specific issue
beads.show("bd-123")

-- Create a new issue
beads.create({ type = "feature" })

-- Execute arbitrary bd command
local result = beads.execute({ "list", "--status", "open" })
```

See `:help nvim-beads_api.txt` for full API documentation.

## Configuration

Good news: there's no configuration needed. The plugin works out of the box.

All issue tracking behavior is controlled by bd itself. See the [bd documentation](https://github.com/steveyegge/beads) for configuration options.

## Documentation

Complete documentation is available via `:help nvim-beads`

## Development

### Running Tests

Initialize the test environment (run once):

```sh
eval $(luarocks path --lua-version 5.1 --bin)
```

Run all tests:

```sh
make test
```

Or using busted directly:

```sh
busted .
```

### Coverage

Generate test coverage reports:

```sh
make coverage-html
```

View the coverage report:

```sh
cd luacov_html && python -m http.server
```

Then open http://localhost:8000 in your browser.

## License

MIT
