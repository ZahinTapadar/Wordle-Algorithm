# Lua Wordle Solver

**[Try it in the browser →](https://zahintapadar.github.io/Wordle-Algorithm/)**

A minimax Wordle solver. For every allowed word it buckets the remaining answers by the colour pattern that guess would produce, and picks the guess whose buckets are smallest (an entropy-style score), with a bonus for words that could themselves be the answer.

- `Lua-Wordle/` — the desktop app: a LÖVE / LuaJIT front end calling the C core (`wordle_core_c.c`) through FFI
- `docs/` — the web version: the same C core compiled to WebAssembly, running in a Web Worker

## Run

Desktop (needs [LÖVE](https://love2d.org) and the compiled `wordle_core` library):

```sh
cd Lua-Wordle && love .
```

Web: rebuild the WebAssembly core with `./build_web.sh`, then serve `docs/` with any static server.

Enter feedback as five digits after each guess: `0` gray, `1` yellow, `2` green.
