# nix esp rust build test

This was an experiment to get slint and esp-rs (std or no_std) to build. I was having a ton of difficulty getting anything to build. With errors that did not lead to any solutions anyone else may have found (unrecognized option 'width'???). 

Unfortunatly, I could not get nix to build an esp project. There where just to many artifacts to get set up correctly. 

I did get the docker build script set up to output the binary which I was then able to flash manually.


# containers

I'm able to build esp-idf projects within the dockerfile found in the root directory. 

I'm also running rust-analyzer through the dockerfile found in ./lsp and I'm asking neovim lspconfig to use that version using a local fennel/lua script loaded at neovim startup.
