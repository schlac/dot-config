local unpack = unpack or table.unpack

-- Build an LSP `cmd` that runs the server in a podman container. Evaluated on
-- every server start so the container mounts the project's root_dir.
local function container_cmd(server)
    return function(dispatchers, config)
        local cmd = require('lspcontainers').command(server, {
            container_runtime = 'podman',
            root_dir = config.root_dir or vim.fn.getcwd(),
        })
        return vim.lsp.rpc.start(cmd, dispatchers)
    end
end

---------------------------------------------------------------------------
-- nvim-cmp helpers
---------------------------------------------------------------------------

local function has_words_before()
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    if col == 0 then
        return false
    end
    local text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
    return text:sub(col, col):match('%s') == nil
end

-- Build a <Tab>/<S-Tab> mapping: select the next/previous item, otherwise
-- open the completion menu, otherwise fall back to the default key behavior.
local function select_or_complete(cmp, select_item)
    return function(fallback)
        if select_item() then
            return
        end
        if vim.bo.buftype ~= 'prompt' and has_words_before() then
            cmp.complete()
        else
            fallback()
        end
    end
end

-- Insert a snippet body at the cursor, keeping the current line's indentation
-- and the text surrounding the cursor.
local function expand_snippet(args)
    local line_num, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line_text = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, true)[1]
    local indent = string.match(line_text, '^%s*')
    local surround = string.match(line_text, '%S.*') or ''
    local surround_end = surround:sub(col)
    local replace = vim.split(args.body, '\n', { plain = true })

    replace[1] = surround:sub(0, col - 1) .. replace[1]
    replace[#replace] = replace[#replace] .. (#surround_end > 1 and ' ' or '') .. surround_end
    if indent ~= '' then
        for i, line in ipairs(replace) do
            replace[i] = indent .. line
        end
    end

    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, replace)
end

---------------------------------------------------------------------------
-- LSP helpers
---------------------------------------------------------------------------

-- Configure lua_ls for Neovim runtime files unless the project has its own
-- .luarc.json(c) (the Neovim config dir itself is always configured here).
local function lua_ls_on_init(client)
    if client.workspace_folders then
        local path = client.workspace_folders[1].name
        local has_luarc = vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')
        if path ~= vim.fn.stdpath('config') and has_luarc then
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
                vim.env.VIMRUNTIME,
                -- Depending on the usage, you might want to add additional paths
                -- here.
                -- '${3rd}/luv/library'
                -- '${3rd}/busted/library'
            },
            -- Or pull in all of 'runtimepath'.
            -- NOTE: this is a lot slower and will cause issues when working on
            -- your own configuration.
            -- See https://github.com/neovim/nvim-lspconfig/issues/3189
            -- library = {
            --   vim.api.nvim_get_runtime_file('', true),
            -- }
        },
    })
end

-- Global diagnostic mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local function set_diagnostic_keymaps()
    vim.keymap.set('n', '<space>q', vim.diagnostic.open_float)
    vim.keymap.set('n', '<space>Q', vim.diagnostic.setloclist)
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
end

-- Buffer-local mappings, set once a language server attaches to a buffer.
-- See `:help vim.lsp.*` for documentation on any of the below functions
local function on_lsp_attach(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    local function map(modes, lhs, rhs)
        vim.keymap.set(modes, lhs, rhs, { buffer = ev.buf })
    end

    map('n', 'gD', vim.lsp.buf.declaration)
    map('n', 'gd', vim.lsp.buf.definition)
    map('n', 'gr', vim.lsp.buf.references)
    map('n', 'gi', vim.lsp.buf.implementation)
    map('n', 'K', vim.lsp.buf.hover)
    map('n', '<C-k>', vim.lsp.buf.signature_help)
    map('n', '<space>D', vim.lsp.buf.type_definition)
    map('n', '<space>rn', vim.lsp.buf.rename)

    map('n', '<space>wa', vim.lsp.buf.add_workspace_folder)
    map('n', '<space>wr', vim.lsp.buf.remove_workspace_folder)
    map('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end)

    map({ 'n', 'x', 'v' }, '<space>ca', vim.lsp.buf.code_action)
    map({ 'n', 'x', 'v' }, '<space>f', function()
        vim.lsp.buf.format { async = true }
    end)
end

---------------------------------------------------------------------------
-- Plugin specs
---------------------------------------------------------------------------

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
        main = "cmp",
        -- opts is a function so require("cmp") only runs when the plugin loads
        opts = function()
            local cmp = require('cmp')
            return {
                sources = {
                    { name = 'nvim_lsp' },
                },

                mapping = {
                    ['<C-Space>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Insert,
                        select = true,
                    },
                    ['<Tab>'] = select_or_complete(cmp, cmp.select_next_item),
                    ['<S-Tab>'] = select_or_complete(cmp, cmp.select_prev_item),
                },

                snippet = { expand = expand_snippet },
            }
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "lspcontainers/lspcontainers.nvim",
        },
        opts = {
            servers = {
                lua_ls = {
                    cmd = container_cmd('lua_ls'),
                    on_init = lua_ls_on_init,
                },

                pyrefly = {
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
                },

                clangd = {
                    cmd = {
                        'clangd',
                        '--header-insertion=never',
                        '-j', tostring(vim.uv.available_parallelism()),
                        '--background-index',
                    },
                    filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
                },

                rust_analyzer = {
                    cmd = container_cmd('rust_analyzer'),
                    settings = {
                        ['rust-analyzer'] = {
                            diagnostics = { enable = true },
                        },
                    },
                },
            },
        },
        config = function(_, opts)
            -- Setup language servers
            for name, config in pairs(opts.servers) do
                vim.lsp.config(name, config)
                vim.lsp.enable(name)
            end

            -- Buffers given on the command line get their FileType event before this
            -- runs, and vim.lsp.enable() doesn't re-trigger them this early in startup.
            if vim.v.vim_did_enter == 0 then
                vim.api.nvim_create_autocmd('VimEnter', {
                    once = true,
                    callback = function()
                        vim.cmd.doautoall('nvim.lsp.enable FileType')
                    end,
                })
            end

            set_diagnostic_keymaps()

            -- Use LspAttach autocommand to only map the following keys
            -- after the language server attaches to the current buffer
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('UserLspConfig', {}),
                callback = on_lsp_attach,
            })
        end,
    },
}
