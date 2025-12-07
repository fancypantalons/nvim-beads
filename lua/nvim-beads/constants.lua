--- Constants and valid values for nvim-beads
local M = {}

--- Valid issue types
M.ISSUE_TYPES = {
    bug = true,
    feature = true,
    task = true,
    epic = true,
    chore = true,
}

--- Valid issue statuses
M.STATUSES = {
    open = true,
    in_progress = true,
    blocked = true,
    closed = true,
    ready = true,
    stale = true,
    all = true,
}

--- Plural to singular mapping for issue types
M.PLURAL_MAP = {
    bugs = "bug",
    features = "feature",
    tasks = "task",
    epics = "epic",
    chores = "chore",
}

return M
