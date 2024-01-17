local lsp_zero = require("lsp-zero").preset({})
local lsp = require("lspconfig")

lsp.lua_ls.setup {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        globals = {
          "vim",
          "require"
        },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
      },
      telemetry = {
        enable = false,
      },
    },
  },
}

lsp.hls.setup({})
lsp.nil_ls.setup({})
lsp.clangd.setup({
  cmd = {
    "clangd",
    "--background-index",
    "--offset-encoding=utf-16",
    "--header-insertion=never",
    "--clang-tidy",
    "--cross-file-rename",
  }
})
lsp.pyright.setup({})

-- ↓ Epitech CS
local configs = require("lspconfig.configs")

if not configs.ecsls then
  configs.ecsls = {
    default_config = {
      root_dir = lsp.util.root_pattern(".git", "Makefile"),
      cmd = { "ecsls_run" },
      autostart = true,
      name = "ecsls",
      filetypes = { "c", "cpp", "make" },
    },
  }
end
lsp.ecsls.setup({})
-- ↓ Epitech HCS
if not configs.ehcsls then
  configs.ehcsls = {
    default_config = {
      root_dir = lsp.util.root_pattern(".git", "Makefile"),
      cmd = { "ehcsls_run" },
      autostart = true,
      name = "ehcsls",
      filetypes = { "haskell", "make" },
    },
  }
end
lsp.ehcsls.setup({})
--

lsp_zero.on_attach(function(_, bufnr)
  local opts = { buffer = bufnr, remap = false }

  vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
  vim.keymap.set("n", "gr", function() vim.lsp.buf.rename() end, opts)
  vim.keymap.set("n", "ga", function() vim.lsp.buf.code_action() end, opts)
  vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)

  lsp_zero.default_keymaps({buffer = bufnr})
end)

lsp_zero.setup()

