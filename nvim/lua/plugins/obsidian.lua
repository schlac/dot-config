return {
    {
        "obsidian-nvim/obsidian.nvim",
        version = "*",  -- recommended, use latest release instead of latest commit
        ft = "markdown",
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- "junegunn/fzf.vim",
            "ibhagwan/fzf-lua",
            "hrsh7th/nvim-cmp",
            -- "MeanderingProgrammer/render-markdown.nvim",
        },
        lazy = false,
        config = function()
            -- only continue if notes dirs exist
            if vim.fn.isdirectory("/home/chrschla/src/schlameuss/notes/") == 0 then
                print("no notes dir 1")
                return
            end
            if vim.fn.isdirectory("/home/chrschla/src/schlac/zettel/") == 0 then
                print("no notes dir 2")
                return
            end

            -- '[[Foo Bar]]'
            ---@param opts obsidian.link.LinkCreationOpts
            ---@return string
            local wiki_link_alias_only = function(opts)
                ---@type string
                local header_or_block = ""
                if opts.anchor then
                    header_or_block = string.format("#%s", opts.anchor.header)
                elseif opts.block then
                    header_or_block = string.format("#%s", opts.block.id)
                end
                return string.format("[[%s%s]]", opts.label, header_or_block)
            end

            -- '[[foo-bar.md|Foo Bar]]'
            ---@param opts obsidian.link.LinkCreationOpts
            ---@return string
            local wiki_link_path_only = function(opts)
                ---@type string
                local header_or_block = ""
                if opts.anchor then
                    header_or_block = opts.anchor.anchor
                elseif opts.block then
                    header_or_block = string.format("#%s", opts.block.id)
                end
                return string.format("[[%s%s]]", opts.path, header_or_block)
            end

            -- '[[foo-bar.md]]'
            ---@param opts obsidian.link.LinkCreationOpts
            ---@return string
            local wiki_link_path_prefix = function(opts)
                local anchor = ""
                local header = ""
                if opts.anchor then
                    anchor = opts.anchor.anchor
                    header = string.format(" ❯ %s", opts.anchor.header)
                elseif opts.block then
                    anchor = "#" .. opts.block.id
                    header = "#" .. opts.block.id
                end

                if opts.label ~= opts.path then
                    return string.format("[[%s%s|%s%s]]", opts.path, anchor, opts.label, header)
                else
                    return string.format("[[%s%s]]", opts.path, anchor)
                end
            end

            require('obsidian').setup {
                legacy_commands = false,
                workspaces = {
                    { name = "work", path = "~/src/schlameuss/notes/", },
                    {
                        name = "personal", path = "~/src/schlac/zettel/",
                        overrides = {
                            daily_notes = { date_format = "%Y-%m", },
                        },
                    },
                },
                daily_notes = {
                    date_format = "%Y/%Y-%m",
                    alias_format = "%Y-%m-%d",
                },

                -- Optional, customize how note IDs are generated given an optional title.
                ---@param title string|?
                ---@return string
                note_id_func = function(title)
                    -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
                    -- In this case a note with the title 'My new note' will be given an ID that looks
                    -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'.
                    -- You may have as many periods in the note ID as you'd like—the ".md" will be added automatically
                    local suffix = ""
                    if title ~= nil then
                        -- If title is given, transform it into valid file name.
                        suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
                    else
                        -- If title is nil, just add 4 random uppercase letters to the suffix.
                        for _ = 1, 4 do
                            suffix = suffix .. string.char(math.random(65, 90))
                        end
                    end
                    return tostring(os.date('%Y%m%d')) .. "-" .. suffix
                end,

                link = {
                    style = wiki_link_alias_only,
                    -- style = wiki_link_path_only
                    -- style = wiki_link_path_prefix
                },

                -- disable_frontmatter = true,
                ui = {
                    -- Define how various check-boxes are displayed
                    checkbox = {
                        order = { " ", "!", "x", },
                        [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
                        ["!"] = { char = "", hl_group = "ObsidianImportant" },
                        ["x"] = { char = "", hl_group = "ObsidianDone" },
                    },
                    bullets = { "■", hl_group = "ObsidianBullet" },
                    external_link_icon = { "" },
                    hl_groups = {
                        ObsidianTodo = { bold = true, fg = "#f78c6c" },
                        ObsidianDone = { bold = true, fg = "#09d00f" },
                        ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
                        ObsidianTilde = { bold = true, fg = "#ff5370" },
                        ObsidianImportant = { bold = true, fg = "#d73128" },
                        ObsidianBullet = { bold = true, fg = "#09d00f" },
                        ObsidianRefText = { underline = true, fg = "#07920a" },
                        ObsidianExtLinkIcon = { fg = "#07920a" },
                        ObsidianTag = { italic = true, fg = "#09d00f" },
                        ObsidianBlockID = { italic = true, fg = "#09d00f" },
                        ObsidianHighlightText = { bg = "#75662e" },
                    },
                },
            }

            -- jump to current month notes file, then go to today's heading (or create it)
            vim.keymap.set("n", "~", function()
                require("obsidian")
                vim.cmd.Obsidian('today')
                vim.cmd.cd('~/src/schlameuss/notes')

                -- defer so the buffer is fully loaded before we inspect/modify it
                vim.schedule(function()
                    local today = os.date('%Y-%m-%d')
                    local heading = '# ' .. today

                    -- search for today's heading in the buffer
                    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
                    for i, line in ipairs(lines) do
                        if line == heading then
                            -- found: jump to it
                            vim.api.nvim_win_set_cursor(0, { i, 0 })
                            return
                        end
                    end

                    -- not found: insert before '# TODAY'
                    for i, line in ipairs(lines) do
                        if line == '# TODAY' then
                            vim.api.nvim_buf_set_lines(0, i - 1, i - 1, false, { heading, '' })
                            vim.api.nvim_win_set_cursor(0, { i, 0 })
                            return
                        end
                    end

                    -- no '# TODAY' marker either: append date heading then TODAY at the end
                    local n = #lines
                    vim.api.nvim_buf_set_lines(0, n, n, false, { '', heading, '', '# TODAY' })
                    vim.api.nvim_win_set_cursor(0, { n + 2, 0 })
                end)
            end)

            -- require('render-markdown').setup({
            --   link = {
            --     wiki = { enabled = true },
            --   },
            -- })
        end,
    },
}
