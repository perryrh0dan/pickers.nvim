# pickers.nvim

Different telescope pickers

# Installation & Usage

```lua
require('lazy').setup({
   "perryrh0dan/pickers.nvim'
})
```

## Diff

Open a telescope picker with all changes between the current HEAD and the default branch.

### Keymaps

```lua
vim.keymap.set('n', '<leader>gd', function()
        require('pickers').diff()
    end, { desc = "Search [G]it [D]iff" })
```
