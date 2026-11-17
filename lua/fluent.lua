-- ServiceNow Fluent language server manager.
-- Layout:  ~/.local/share/fluent-ls/versions/<ver>/   (unpacked .vsix "extension/" dir)
--          ~/.local/share/fluent-ls/current -> versions/<ver>
local M = {}

local ext_api = "https://open-vsx.org/api/ServiceNow/fluent-language-extension"
local root = vim.fn.expand("~/.local/share/fluent-ls")

M.server = root .. "/current/dist/desktop/server.js"

function M.installed()
    local target = vim.uv.fs_readlink(root .. "/current")
    return target and vim.fs.basename(target) or nil
end

local function notify(msg, level)
    vim.schedule(function() vim.notify("Fluent LS: " .. msg, level or vim.log.levels.INFO) end)
end

-- Run a command asynchronously; cb(ok, stdout)
local function run(cmd, cb)
    vim.system(cmd, { text = true }, function(res)
        cb(res.code == 0, res.stdout or "", res.stderr or "")
    end)
end

-- Restart the client so it picks up the new server
local function restart()
    vim.schedule(function()
        vim.lsp.enable("fluent", false)
        vim.defer_fn(function() vim.lsp.enable("fluent") end, 200)
    end)
end

function M.update()
    for _, bin in ipairs({ "curl", "unzip" }) do
        if vim.fn.executable(bin) == 0 then
            return notify(bin .. " not found in PATH", vim.log.levels.ERROR)
        end
    end

    notify("checking for updates...")
    run({ "curl", "-fsSL", ext_api }, function(ok, out)
        if not ok then return notify("could not reach Open VSX", vim.log.levels.ERROR) end

        local parsed, meta = pcall(vim.json.decode, out)
        if not parsed or type(meta) ~= "table" or not meta.version
            or not (meta.files and meta.files.download) then
            return notify("unexpected response from Open VSX", vim.log.levels.ERROR)
        end

        local version, url = meta.version, meta.files.download
        if version == M.installed() then
            return notify("already up to date (" .. version .. ")")
        end

        local dest = root .. "/versions/" .. version
        local tmp = vim.fn.tempname()
        local vsix = tmp .. ".vsix"
        notify("downloading " .. version .. "...")

        run({ "curl", "-fsSL", "-o", vsix, url }, function(dl_ok)
            if not dl_ok then return notify("download failed", vim.log.levels.ERROR) end

            vim.fn.mkdir(tmp, "p")
            run({ "unzip", "-q", "-o", vsix, "extension/*", "-d", tmp }, function(un_ok)
                vim.schedule(function()
                    vim.fn.delete(vsix)
                    local src = tmp .. "/extension"
                    if not un_ok or not vim.uv.fs_stat(src .. "/dist/desktop/server.js") then
                        vim.fn.delete(tmp, "rf")
                        return notify("extraction failed or server.js missing", vim.log.levels.ERROR)
                    end

                    vim.fn.mkdir(root .. "/versions", "p")
                    vim.fn.delete(dest, "rf")
                    if vim.fn.rename(src, dest) ~= 0 then
                        vim.fn.delete(tmp, "rf")
                        return notify("could not move into " .. dest, vim.log.levels.ERROR)
                    end
                    vim.fn.delete(tmp, "rf")

                    -- atomic symlink swap
                    local link_tmp = root .. "/current.new"
                    vim.fn.delete(link_tmp)
                    vim.uv.fs_symlink("versions/" .. version, link_tmp)
                    vim.uv.fs_rename(link_tmp, root .. "/current")

                    notify("updated to " .. version .. ", restarting")
                    restart()
                end)
            end)
        end)
    end)
end

return M
