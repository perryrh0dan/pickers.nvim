local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require('telescope.previewers')
local conf = require("telescope.config").values
local utils = require("telescope.utils")
local entry_display = require('telescope.pickers.entry_display')

local strings = require "plenary.strings"
local Job = require('plenary.job')

local get_default_branch = "git rev-parse --symbolic-full-name refs/remotes/origin/HEAD | sed 's!.*/!!'"
local base_branch = vim.fn.system("git merge-base HEAD origin/" .. (vim.fn.system(get_default_branch) or "master"))

base_branch = base_branch:gsub("[\r\n]", "")

local M = {}

M.diff = function()
    local output_lines = {}

    local job = Job:new({
        command = "git",
        args = { "diff", "--name-only", "--cached", base_branch },
        on_stdout = function(_, line)
            table.insert(output_lines, line)
        end,
        on_stderr = function(a, b)
            vim.print(a)
            vim.print(b)
        end,
        on_exit = function(_, exit_code, _)
            if exit_code == 0 then
                vim.schedule(function()
                    M.openPicker(output_lines)
                end)
            else
                print('Job failed with exit code:', exit_code)
            end
        end,
    })

    job:start()
end

M.staged = function()
    local output_lines = {}

    local output = vim.fn.system("git status --porcelain | sed s/^...//")

    for line in output:gmatch("[^\r\n]+") do
        table.insert(output_lines, line)
    end

    vim.schedule(
        function()
            M.openPicker(output_lines)
        end
    )
end

M.openPicker = function(filePaths)
    local icon, _ = utils.get_devicons("fname")
    local icon_width = strings.strdisplaywidth(icon)

    local displayer = entry_display.create {
        separator = " ",
        items = {
            { width = icon_width },
            { remaining = true },
        },
    }

    local make_display = function(entry)
        local display_path, path_style = utils.transform_path({
            path_display = {
                filename_first = {
                    reverse_directories = false,
                }
            }
        }, entry.path)
        local icon, hl_group = utils.get_devicons(entry.path)

        return displayer({
            { icon, hl_group },
            {
                display_path,
                function()
                    return path_style
                end
                ,
            },
        })
    end

    local entry_maker = function(entry)
        return {
            value = entry,
            display = make_display,
            ordinal = entry,
            path = entry,
        }
    end

    local git_diff_previewer = previewers.new({
        title = "Git Diff",
        preview_fn = function(self, entry, status)
            local filepath = entry.value
            local buf = status.preview_bufnr
            if not vim.api.nvim_buf_is_valid(buf) then
                vim.print("Preview buffer is not valid: " .. buf)
                return
            end

            vim.api.nvim_set_option_value('filetype', 'diff', { buf = buf })

            local output_lines = {}

            Job:new({
                command = 'git',
                args = { 'diff', 'master', '--', filepath },
                cwd = vim.loop.cwd(),
                on_stdout = function(_, line)
                    table.insert(output_lines, line)
                    -- Schedule buffer update on the main thread
                end,
                on_stderr = function(a, data)
                    if data then
                        vim.print("stderr: " .. data) -- Debug stderr output
                    end
                end,
                on_exit = function()
                    vim.schedule(function()
                        vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
                    end)
                end
            }):start()
        end,
    })

    pickers.new({}, {
        prompt_title = "Git diff between HEAD and " .. string.gsub(base_branch, '\n', ''),
        finder = finders.new_table {
            results = filePaths,
            entry_maker = entry_maker,
        },
        previewer = git_diff_previewer,
        sorter = conf.generic_sorter(opts),
    }):find()
end

return M
