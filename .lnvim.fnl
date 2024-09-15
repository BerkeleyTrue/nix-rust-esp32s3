; this file is loaded by nvim-local-fennel on neovim startup when in this directory
(let [lspconfig (require :lspconfig)
      wd (os.getenv "PWD")]
  ; this sets up lspconfig to run rust analyzer through the created docker container
  ; for this project
  (lspconfig.rust_analyzer.setup {:cmd [:docker :run :-i :--rm :-v (.. wd ":" wd) :rust-analyzer :rust-analyzer]}))
