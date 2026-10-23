return {
    -- fuzzy finder
    { "junegunn/fzf", build = "./install --all", version = "*", },
    {
        "ibhagwan/fzf-lua",
        lazy = false,
        dependencies = { "junegunn/fzf", "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<leader>p",  "<cmd>Files<cr>",                                                              desc = "fuzzy find files" },
            { "<leader>b",  "<cmd>Buffers<cr>",                                                            desc = "show open buffers" },
            { "<leader>gg", "<cmd>Rg<cr>",                                                                 desc = "grep in files" },
            { "<leader>g",  function() require("fzf-lua").grep({ search = vim.fn.expand("<cword>") }) end, desc = "grep word under cursor" },
            { "<leader>f",  function() require("fzf-lua").tags({ query = vim.fn.expand("<cword>") }) end,  desc = "jump to tag under cursor" },
        },
        opts = {
            -- base profile (hides the prompt decoration)
            [1] = "default-prompt",
            desc = "fzf.vim like config",
            winopts = {
                -- preview = { vertical = "down:80%", },
                treesitter = {
                    enabled = false,
                },
            },
            fzf_opts = {
                -- nullify fzf-lua's settings to inherit from FZF_DEFAULT_OPTS
                ["--info"]   = false,
                ["--layout"] = false,
            },
            files = {
                cmd = os.getenv("FZF_DEFAULT_COMMAND"),
                cwd_prompt = true,
                cwd_prompt_shorten_len = 1,
            },
        },
        config = function(_, opts)
            local fzf_lua = require("fzf-lua")
            local actions = fzf_lua.actions
            local utils = fzf_lua.utils

            -- actions reference fzf_lua.actions so must be added here, not in opts
            opts.actions = {
                files = {
                    ["enter"]  = actions.file_edit_or_qf,
                    ["ctrl-x"] = actions.file_split,
                    ["ctrl-v"] = actions.file_vsplit,
                    ["ctrl-t"] = actions.file_tabedit,
                    ["alt-q"]  = actions.file_sel_to_qf,
                    ["alt-l"]  = actions.file_sel_to_ll,
                },
            }

            fzf_lua.setup(opts)

            -- register fzf.vim-compatible user commands
            local function cmd_exists(cmd)
                local ret = vim.fn.exists(":" .. cmd)
                return type(ret) == "number" and ret ~= 0
            end

            local function setup_commands(no_override, prefix)
                local cmds = {
                    ["Files"]     = utils.create_user_command_callback("files", "cwd"),
                    ["GFiles"]    = utils.create_user_command_callback("git_files", "cwd", { ["?"] = "git_status" }),
                    ["Buffers"]   = utils.create_user_command_callback("buffers"),
                    ["Colors"]    = utils.create_user_command_callback("colorschemes"),
                    ["Rg"]        = utils.create_user_command_callback("grep", "search"),
                    ["RG"]        = utils.create_user_command_callback("live_grep", "search"),
                    ["Lines"]     = utils.create_user_command_callback("lines", "query"),
                    ["BLines"]    = utils.create_user_command_callback("blines", "query"),
                    ["Tags"]      = utils.create_user_command_callback("tags", "query"),
                    ["BTags"]     = utils.create_user_command_callback("btags", "query"),
                    ["Changes"]   = utils.create_user_command_callback("changes"),
                    ["Marks"]     = utils.create_user_command_callback("marks"),
                    ["Jumps"]     = utils.create_user_command_callback("jumps"),
                    ["Commands"]  = utils.create_user_command_callback("commands"),
                    ["History"]   = utils.create_user_command_callback("history", "query", {
                        [":"] = "command_history",
                        ["/"] = "search_history",
                    }),
                    ["Commits"]   = utils.create_user_command_callback("git_commits", "query"),
                    ["BCommits"]  = utils.create_user_command_callback("git_bcommits", "query"),
                    ["Maps"]      = utils.create_user_command_callback("keymaps", "query"),
                    ["Helptags"]  = utils.create_user_command_callback("help_tags", "query"),
                    ["Filetypes"] = utils.create_user_command_callback("filetypes", "query"),
                }

                for cmd, cb in pairs(cmds) do
                    cmd = (prefix or "") .. cmd
                    if not cmd_exists(cmd) or no_override ~= true then
                        pcall(vim.api.nvim_del_user_command, cmd)
                        vim.api.nvim_create_user_command(cmd, cb, { bang = true, nargs = "?" })
                    end
                end
            end

            setup_commands()
        end,
    },
}
