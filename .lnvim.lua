local _2afile_2a = ".lnvim.fnl"
local lspconfig = require("lspconfig")
local wd = os.getenv("PWD")
return lspconfig.rust_analyzer.setup({cmd = {"docker", "run", "-i", "--rm", "-v", (wd .. ":" .. wd), "rust-analyzer", "rust-analyzer"}})