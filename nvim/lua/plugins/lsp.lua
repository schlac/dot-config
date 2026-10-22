return {
    {
        "hrsh7th/nvim-cmp",
        -- load cmp on InsertEnter
        event = "InsertEnter",
        -- these dependencies will only be loaded when cmp loads
        -- dependencies are always lazy-loaded unless specified otherwise
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
        },
        config = function()
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
            end

            local cmp = require('cmp')
            cmp.setup {
                sources = {
                    { name = 'nvim_lsp' },
                },

                mapping = {
                    ['<C-Space>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Insert,
                        select = true,
                    },

                    ['<Tab>'] = function(fallback)
                        if not cmp.select_next_item() then
                            if vim.bo.buftype ~= 'prompt' and has_words_before() then
                                cmp.complete()
                            else
                                fallback()
                            end
                        end
                    end,

                    ['<S-Tab>'] = function(fallback)
                        if not cmp.select_prev_item() then
                            if vim.bo.buftype ~= 'prompt' and has_words_before() then
                                cmp.complete()
                            else
                                fallback()
                            end
                        end
                    end,
                },

                snippet = {
                    expand = function(args)
                        unpack = unpack or table.unpack
                        local line_num, col = unpack(vim.api.nvim_win_get_cursor(0))
                        local line_text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
                        local indent = string.match(line_text, '^%s*')
                        local replace = vim.split(args.body, '\n', true)
                        local surround = string.match(line_text, '%S.*') or ''
                        local surround_end = surround:sub(col)

                        replace[1] = surround:sub(0, col - 1)..replace[1]
                        replace[#replace] = replace[#replace]..(#surround_end > 1 and ' ' or '')..surround_end
                        if indent ~= '' then
                            for i, line in ipairs(replace) do
                                replace[i] = indent..line
                            end
                        end

                        vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, replace)
                    end,
                },
            }
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "lspcontainers/lspcontainers.nvim",
        },
        config = function()
            -- Setup language servers

            vim.lsp.enable('lua_ls', {
                cmd = require'lspcontainers'.command('lua_ls', {
                    container_runtime = "podman",
                }),
                on_init = function(client)
                    if client.workspace_folders then
                        local path = client.workspace_folders[1].name
                        if
                            path ~= vim.fn.stdpath('config')
                            and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
                        then
                            return
                        end
                    end
                    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                        runtime = {
                            -- Tell the language server which version of Lua you're using (most
                            -- likely LuaJIT in the case of Neovim)
                            version = 'LuaJIT',
                            -- Tell the language server how to find Lua modules same way as Neovim
                            -- (see `:h lua-module-load`)
                            path = {
                                'lua/?.lua',
                                'lua/?/init.lua',
                            },
                        },
                        -- Make the server aware of Neovim runtime files
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                vim.env.VIMRUNTIME
                                -- Depending on the usage, you might want to add additional paths
                                -- here.
                                -- '${3rd}/luv/library'
                                -- '${3rd}/busted/library'
                            }
                            -- Or pull in all of 'runtimepath'.
                            -- NOTE: this is a lot slower and will cause issues when working on
                            -- your own configuration.
                            -- See https://github.com/neovim/nvim-lspconfig/issues/3189
                            -- library = {
                            --   vim.api.nvim_get_runtime_file('', true),
                            -- }
                        },
                    })
                end,
            })

            vim.lsp.config('pyrefly', {
                cmd = { 'pyrefly', 'lsp' },
                filetypes = { 'python' },
                root_markers = {
                    'pyrefly.toml',
                    'pyproject.toml',
                    'setup.py',
                    'setup.cfg',
                    'requirements.txt',
                    'Pipfile',
                    '.git',
                },
                on_exit = function(code, _, _)
                    vim.notify('Closing Pyrefly LSP exited with code: ' .. code, vim.log.levels.INFO)
                end,
            })
            vim.lsp.enable({'pyrefly'})

            local nproc = string.gsub(vim.fn.system('nproc'), "\n", "")
            vim.lsp.enable('clangd', {
                cmd = {
                    "clangd",
                    "--header-insertion=never",
                    "-j", nproc,
                    "--background-index",
                },
                filetypes = {"c", "cpp", "objc", "objcpp"},
            })

            vim.lsp.enable('rust_analyzer', {
                settings = {
                    ['rust-analyzer'] = {
                        cmd = require'lspcontainers'.command(
                            'rust_analyzer', {
                                container_runtime = "podman",
                            }),
                        diagnostics = {
                            enable = true,
                        },
                    }
                }
            })

            -- Global mappings.
            -- See `:help vim.diagnostic.*` for documentation on any of the below functions
            vim.keymap.set('n', '<space>q', vim.diagnostic.open_float)
            vim.keymap.set('n', '<space>Q', vim.diagnostic.setloclist)
            vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)

            -- Use LspAttach autocommand to only map the following keys
            -- after the language server attaches to the current buffer
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('UserLspConfig', {}),
                callback = function(ev)
                    -- Enable completion triggered by <c-x><c-o>
                    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

                    -- Buffer local mappings.
                    -- See `:help vim.lsp.*` for documentation on any of the below functions
                    local opts = { buffer = ev.buf }
                    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
                    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
                    vim.keymap.set('n', '<space>wl', function()
                        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                    end, opts)
                    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
                    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set({ 'n', 'x', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set({ 'n', 'x', 'v' }, '<space>f', function()
                        vim.lsp.buf.format { async = true }
                    end, opts)
                end,
            })
        end,
    },
}
