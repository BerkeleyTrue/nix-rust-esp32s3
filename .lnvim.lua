local _2afile_2a = "/home/berkeleytrue/dvlpmnt/rust/nix-rust-esp32s3/.lnvim.fnl"
local lspconfig = require("lspconfig")
local wd = os.getenv("PWD")
return vim.lsp.config("rust_analyzer", {cmd = {"docker", "run", "-i", "--rm", "-v", (wd .. ":" .. wd), "rust-analyzer", "rust-analyzer"}})