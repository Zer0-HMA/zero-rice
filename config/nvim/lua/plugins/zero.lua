-- Lo que ZERO agrega o cambia sobre LazyVim
return {
  -- ── Colores: los de tu paleta (ver lua/zero/init.lua) ──
  { "nvim-mini/mini.base16", lazy = true },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local zero = require("zero")
        zero.aplicar()
        zero.vigilar()
      end,
    },
  },

  -- ── Pantalla de inicio con el logo de ZERO ──
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
███████╗███████╗██████╗  ██████╗
╚══███╔╝██╔════╝██╔══██╗██╔═══██╗
  ███╔╝ █████╗  ██████╔╝██║   ██║
 ███╔╝  ██╔══╝  ██╔══██╗██║   ██║
███████╗███████╗██║  ██║╚██████╔╝
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ]],
        },
      },
    },
  },

  -- ── Línea de estado redondeada, como las islas de la barra ──
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.component_separators = { left = "", right = "" }
      opts.options.section_separators = { left = "", right = "" }
    end,
  },

  -- ── Grupo <leader>z en which-key ──
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { "<leader>z", group = "zero-rice", icon = "󰏘 " })
    end,
  },

  -- ── Resaltado para los archivos del rice ──
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "bash", "css", "lua", "tsx", "typescript", "rasi", "jsonc", "toml", "ini",
      })
    end,
  },

  -- ── Herramientas para tus scripts de bash y el CSS de la barra ──
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "shellcheck", "shfmt", "bash-language-server", "css-lsp" })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { bashls = {}, cssls = {} } },
  },
}
