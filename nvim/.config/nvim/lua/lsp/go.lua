-- Example lspconfig setup for gopls
require("lspconfig").gopls.setup({
  settings = {
    gopls = {
      completeUnimported = true, -- Automatically import packages
      usePlaceholders = true, -- Add placeholders for function parameters
    },
  },
})
