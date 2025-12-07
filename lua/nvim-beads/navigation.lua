--- Navigation utilities for beads buffers
--- Provides functionality for navigating between issue references

---@class nvim-beads.navigation
local M = {}

--- Cached repository prefix
---@type string|nil
local cached_prefix = nil

--- Get the repository issue ID prefix by querying bd
--- This works even for new issue buffers by querying any existing issue
---@return string|nil prefix The issue ID prefix (e.g., "nvim-beads"), or nil on error
---@return string? error Error message if prefix detection fails
local function get_repo_prefix()
    -- Return cached value if available
    if cached_prefix then
        return cached_prefix, nil
    end

    local core = require("nvim-beads.core")

    -- Query for a single issue to extract the prefix
    local result, err = core.execute_bd({ "list", "--all", "--limit", "1" })
    if err then
        return nil, string.format("Failed to detect issue prefix: %s", err)
    end

    -- Extract prefix from the first issue ID
    if type(result) == "table" and #result > 0 and result[1].id then
        local issue_id = result[1].id
        -- Issue IDs have format: prefix-suffix (e.g., "nvim-beads-5ia")
        -- Extract everything before the last hyphen and alphanumeric suffix
        local prefix = issue_id:match("^(.+)%-[a-zA-Z0-9]+$")
        if prefix then
            cached_prefix = prefix
            return prefix, nil
        end
    end

    return nil, "Could not extract issue prefix from repository"
end

--- Extract issue ID from text under cursor
--- Uses <cWORD> to get word including hyphens and special characters
---@return string|nil issue_id The extracted issue ID, or nil if none found
local function extract_issue_id_at_cursor()
    -- Get the WORD under cursor (includes hyphens, unlike <cword>)
    local word = vim.fn.expand("<cWORD>")
    if not word or word == "" then
        return nil
    end

    -- Get repository prefix
    local prefix, err = get_repo_prefix()
    if err then
        vim.notify(err, vim.log.levels.WARN)
        return nil
    end

    -- Build pattern: prefix-[alphanumeric]+
    -- Must escape prefix for pattern matching
    local escaped_prefix = vim.pesc(prefix)
    local pattern = "(" .. escaped_prefix .. "%-[a-zA-Z0-9]+)"

    -- Extract issue ID from the word
    local issue_id = word:match(pattern)
    return issue_id
end

--- Navigate to an issue referenced under the cursor
--- Extracts issue ID from cursor position and opens it in a beads buffer
---@return boolean success True if navigation succeeded
function M.navigate_to_issue_at_cursor()
    local issue_id = extract_issue_id_at_cursor()

    if not issue_id then
        -- Silent failure as per design decision
        return false
    end

    -- Open the issue buffer
    local buffer = require("nvim-beads.buffer")
    return buffer.open_issue_buffer(issue_id)
end

--- Setup buffer-local navigation keymaps
--- Should be called when setting up beads buffers
---@param bufnr number The buffer number to set up keymaps for
function M.setup_buffer_keymaps(bufnr)
    -- Map Enter key to navigate to issue under cursor
    vim.keymap.set("n", "<CR>", function()
        M.navigate_to_issue_at_cursor()
    end, {
        buffer = bufnr,
        silent = true,
        desc = "Navigate to issue under cursor",
    })
end

return M
