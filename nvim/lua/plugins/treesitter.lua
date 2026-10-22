return {
    -- syntax coloring
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main", -- Make sure you are tracking the modern branch
      build = ":TSUpdate",
      --lazy = false, -- Treesitter must load early
      config = function()
        local ts = require("nvim-treesitter")

        -- 1. Setup the core plugin directory
        ts.setup({
          install_dir = vim.fn.stdpath("data") .. "/site"
        })

        -- 2. Bootstrap your core languages (Replaces ensure_installed)
        ts.install({
          "bash",
          "c",
          "go",
          "json",
          "lua",
          "make",
          "markdown",
          "markdown_inline",
          "python",
          "rust",
          "vim",
          "vimdoc",
          "yaml",
          "xml"
        })

        -- 3. Enable Highlighting via Native Autocommands
        vim.api.nvim_create_autocmd("FileType", {
          pattern = {
            "bash",
            "c",
            "go",
            "json",
            "lua",
            "make",
            "markdown",
            "python",
            "rust",
            "vim",
            "yaml",
            "xml"
          },
          callback = function()
            vim.treesitter.start()
          end,
        })

        -- 4. Enable Experimental Indentation (Replaces indent = { enable = true })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "go", "lua", "python", "rust" }, -- add languages you want auto-indented
          callback = function()
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end,
        })
      end,
    },

    -- 5. Bring back dynamic auto-installation for inline markdown languages
    {
      "mks-h/treesitter-autoinstall.nvim",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      opts = {},
    },

    -- context line
    {
        "nvim-treesitter/nvim-treesitter-context", build = ":TSUpdate", version = "*",
        opts = {
            enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
            multiwindow = false, -- Enable multiwindow support.
            max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
            min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
            line_numbers = true,
            multiline_threshold = 20, -- Maximum number of lines to show for a single context
            trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
            mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
            -- Separator between context and content. Should be a single character string, like '-'.
            -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
            separator = nil,
            zindex = 20, -- The Z-index of the context window
            on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
        }
    },
}
