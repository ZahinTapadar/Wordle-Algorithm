// Runs the C minimax core (compiled to WebAssembly) off the main thread.
// Mirrors main.lua: compute the best guess, apply 0/1/2 feedback, repeat.

let E, buf, words, count = 0;

const mem = () => new Uint8Array(E.memory.buffer);

function getWord(i) {
  const m = mem();
  let o = E.get_word(i), s = '';
  while (m[o]) s += String.fromCharCode(m[o++]);
  return s.toUpperCase();
}

function load() {
  // The buffer doubles as scratch space, so rewrite the word lists on every reset
  mem().set(words, buf);
  return E.load_words_buf();
}

function remaining() {
  const out = [];
  for (let i = 0; i < count; i++) {
    if (E.get_is_possible(i)) out.push([getWord(i), E.get_is_answer(i) === 1]);
  }
  return out;
}

let bestIdx = 0;

function solve() {
  const start = performance.now();
  bestIdx = E.calculate_best_move(buf);
  const ms = performance.now() - start;
  const score = new Int32Array(E.memory.buffer, buf, 1)[0];
  const list = remaining();
  postMessage({ state: 'WAITING_INPUT', best: getWord(bestIdx), score, ms, remaining: list.length, words: list });
}

onmessage = async ({ data }) => {
  if (data.type === 'init') {
    const [wasm, allowed, possible] = await Promise.all([
      fetch('wordle_core.wasm').then(r => r.arrayBuffer()),
      fetch('allowed_words.txt').then(r => r.text()),
      fetch('possible_words.txt').then(r => r.text())
    ]);
    E = (await WebAssembly.instantiate(wasm)).instance.exports;
    buf = E.get_io_buf();
    words = new TextEncoder().encode(allowed + '\0' + possible + '\0');
    count = load();
    solve();
  } else if (data.type === 'reset') {
    load();
    solve();
  } else if (data.type === 'feedback') {
    const left = E.filter_possible(bestIdx, data.pattern);
    if (left === 1) {
      const list = remaining();
      postMessage({ state: 'SOLVED', best: list[0][0], remaining: 1, words: list });
    } else if (left === 0) {
      postMessage({ state: 'ERROR', remaining: 0, words: [] });
    } else {
      solve();
    }
  }
};
