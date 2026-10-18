#!/bin/sh
# Compile the C minimax core to WebAssembly for the browser build in docs/.
# Needs a clang with the wasm32 target (e.g. Homebrew llvm) and a wasm linker
# (wasm-ld, or rust-lld from a Rust toolchain).
set -e
cd "$(dirname "$0")"
CLANG=${CLANG:-$(brew --prefix llvm 2>/dev/null)/bin/clang}
LINKER=${WASM_LD:-$(command -v wasm-ld || ls ~/.rustup/toolchains/*/lib/rustlib/*/bin/rust-lld | head -1)}
OBJ=$(mktemp -t wordle_core).o
case "$LINKER" in *rust-lld) FLAVOR="-flavor wasm" ;; *) FLAVOR="" ;; esac

"$CLANG" --target=wasm32 -O3 -DWORDLE_WASM -Wall -nostdlib -fno-builtin -mbulk-memory \
  -c Lua-Wordle/wordle_core_c.c -o "$OBJ"
"$LINKER" $FLAVOR --no-entry \
  --export=get_io_buf --export=load_words_buf --export=filter_possible --export=calculate_best_move \
  --export=get_word --export=get_is_possible --export=get_is_answer \
  -o docs/wordle_core.wasm "$OBJ"
cp Lua-Wordle/allowed_words.txt Lua-Wordle/possible_words.txt docs/
rm -f "$OBJ"
echo "Built docs/wordle_core.wasm. Serve docs/ with any static server."
