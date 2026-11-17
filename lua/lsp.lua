require("mason").setup()

vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, { desc = "Format Local buffer" })
vim.keymap.set("n", "df", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

vim.diagnostic.config({ virtual_text = true })

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("mini.completion").get_lsp_capabilities())

vim.lsp.config("*", { capabilities = capabilities })

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" } },
        },
    },
})

--ServiceNow SDK projects are identified by now.config.json
local now_root = {"now.config.json", "tsconfig.json", "package.json", ".git"}


-- TypeScript / Fluent types (.now.ts fiels have filetype "TypeScript")
vim.lsp.config("ts_ls", {root_markers = now_root}) 

-- Optional Lint
vim.lsp.config("eslint", {root_markers = now_root}) 


-- ServiceNow Fluent language server (from the VS Code extension, step 4)
-- Installed/updated with :FluentUpdate (see fluent.lua)
local fluent_server = require("fluent").server
local has_fluent = vim.uv.fs_stat(fluent_server) ~= nil

if has_fluent then
    vim.lsp.config("fluent", {
        cmd = { "node", fluent_server, "--stdio" },
        filetypes = { "typescript", "javascript", "json" },
        root_markers = { "now.config.json" }, -- only inside SDK projects
        -- init_options = { },               -- fill in from step 4 if the client sends any
    })
end

vim.lsp.enable({
    "lua_ls",
    "marksman",
    "gopls",
    "rust_analyzer",
    "ts_ls",
    "eslint",
})

if has_fluent then vim.lsp.enable("fluent") end
