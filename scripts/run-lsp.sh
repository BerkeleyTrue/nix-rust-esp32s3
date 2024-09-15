set -o pipefail

# This script is used to run the LSP server in a Docker container.
# ./scripts/run-lsp.sh <args>
# example: ./scripts/run-lsp.sh --help
docker run -i --rm -v "$(pwd):$(pwd)" rust-analyzer rust-analyzer "$@"
