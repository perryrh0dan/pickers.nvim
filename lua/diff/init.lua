local M = {}

M.open = function()
    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local previewers = require "telescope.previewers"
    local conf = require("telescope.config").values

    local get_default_branch = "git rev-parse --symbolic-full-name refs/remotes/origin/HEAD | sed 's!.*/!!'"
    local base_branch = vim.fn.system(get_default_branch) or "main"

    local colors = function(opts)
        opts = opts or {}

        local command = "git diff --name-only $(git merge-base HEAD " .. base_branch .. " )"

        local handle = io.popen(command)

        local output = handle:read("*a")

        handle:close()

        local list = {}
        for token in string.gmatch(output, "[^%c]+") do
            table.insert(list, token)
        end

        local entry_maker = function(entry)
            return {
                value = entry,
                display = entry,
                ordinal = entry,
                path = entry,
            }
        end

        pickers.new(opts, {
            prompt_title = "Git diff",
            finder = finders.new_table {
                results = list,
                entry_maker = entry_maker,
            },
            previewer = conf.file_previewer {},
            sorter = conf.generic_sorter(opts),
        }):find()
    end

    colors()
end

return M
