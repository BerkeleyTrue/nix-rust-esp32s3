(let [lspconfig (require :lspconfig)
      wd (os.getenv "PWD")]
  (lspconfig.rust_analyzer.setup {:cmd [:docker :run :-i :--rm :-v (.. wd ":" wd) :rust_analyzer_test :rust-analyzer]}))
