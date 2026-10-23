# wortraum

*Wortraum*: German for "word space". An information-theoretic Wordle solver in Lua, C, and WebAssembly.

**[Try it in the browser →](https://zahintapadar.github.io/wortraum/)**

For every allowed word it buckets the remaining answers by the colour pattern that guess would produce, and picks the guess with the lowest Σ n·log₂ n over those buckets: the guess with the highest expected information. Words that could themselves be the answer get a bonus. The [devlog](https://zahin-tapadar.vercel.app/blog/making-a-wordle-solver-that-actually-thinks/) explains how it works.

- `Lua-Wordle/` — the desktop app: a LÖVE / LuaJIT front end calling the C core (`wordle_core_c.c`) through FFI
- `docs/` — the web version: the same C core compiled to WebAssembly, running in a Web Worker

## Run

Desktop (needs [LÖVE](https://love2d.org) and the compiled `wordle_core` library):

```sh
cd Lua-Wordle && love .
```

Web: rebuild the WebAssembly core with `./build_web.sh`, then serve `docs/` with any static server.

Enter feedback as five digits after each guess: `0` gray, `1` yellow, `2` green.
