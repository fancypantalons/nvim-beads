--- Health check module for nvim-beads
--- Neovim automatically discovers this when running :checkhealth nvim-beads

local M = {}

--- Main health check function called by :checkhealth
function M.check()
    vim.health.start("nvim-beads")

    -- Check 1: bd executable
    local bd_found = false
    if vim.fn.executable("bd") == 1 then
        vim.health.ok("bd executable found in PATH")
        bd_found = true
    else
        vim.health.error("bd executable not found in PATH", {
            "Install bd from https://github.com/steveyegge/beads",
        })
    end

    -- Check 2: bd repository setup (run bd doctor and parse all checks)
    if bd_found then
        local result = vim.system({ "bd", "doctor", "--json" }, { text = true }):wait()
        if result.code ~= 0 and result.code ~= 1 then
            -- bd doctor returns exit code 1 if there are warnings, so only error on other codes
            vim.health.warn("bd doctor check failed - repository may not be initialized", {
                result.stderr or "Unknown error",
            })
        else
            local ok, data = pcall(vim.json.decode, result.stdout)
            if ok and data.checks then
                -- Report bd CLI version from doctor output
                if data.cli_version then
                    vim.health.info("bd CLI version: " .. data.cli_version)
                end

                -- Iterate through each individual health check from bd doctor
                for _, check in ipairs(data.checks) do
                    local msg = check.name .. ": " .. check.message
                    local advice = nil

                    -- Build advice from fix or detail fields
                    if check.fix then
                        advice = { check.fix }
                    elseif check.detail then
                        advice = { check.detail }
                    end

                    if check.status == "ok" then
                        vim.health.ok(msg)
                    elseif check.status == "warning" then
                        vim.health.warn(msg, advice)
                    elseif check.status == "error" then
                        vim.health.error(msg, advice)
                    end
                end
            else
                vim.health.warn("Failed to parse bd doctor output")
            end
        end
    end

    -- Check 3: Telescope
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
        vim.health.ok("telescope.nvim is installed")
    else
        vim.health.error("telescope.nvim not found", {
            "Install from https://github.com/nvim-telescope/telescope.nvim",
        })
    end
end

return M
