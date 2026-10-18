#ifdef WORDLE_WASM
/* Freestanding WebAssembly build for the browser (no libc): provide the few
 * routines the solver uses and load the word lists from memory, not files. */
void *memset(void *d, int c, unsigned long n) {
  unsigned char *p = d;
  while (n--) *p++ = (unsigned char)c;
  return d;
}
static int strcmp(const char *a, const char *b) {
  while (*a && *a == *b) a++, b++;
  return (unsigned char)*a - (unsigned char)*b;
}
#else
#include <stdio.h>
#include <string.h>
#endif

char w[13000][6], v[13000], q[13000];
int N = 0, L[13000];

int cmp(char *g, char *a) {
  int p = 0, au = 0, gu = 0, m[5] = {1, 3, 9, 27, 81};
  for (int i = 0; i < 5; ++i)
    if (g[i] == a[i])
      p += 2 * m[i], au |= 1 << i, gu |= 1 << i;
  for (int i = 0; i < 5; ++i)
    if (!(gu & (1 << i)))
      for (int j = 0; j < 5; ++j)
        if (!(au & (1 << j)) && g[i] == a[j]) {
          p += m[i];
          au |= 1 << j;
          break;
        }
  return p;
}

void init_tables() {
  for (int i = 1; i < 13000; i++) {
    int l = 31 - __builtin_clz(i);
    L[i] = i * (l * 256 + ((i - (1 << l)) * 256) / (1 << l));
  }
}

static void reset_words(void) {
  init_tables();
  N = 0;
  memset(v, 0, sizeof(v));
  memset(q, 0, sizeof(q));
}

static void add_allowed(const char *word) {
  if (N >= 13000) return;
  for (int i = 0; i < 5; i++) w[N][i] = word[i];
  w[N][5] = '\0';
  N++;
}

static int mark_possible(const char *word) {
  for (int i = 0; i < N; i++) {
    if (!strcmp(w[i], word)) {
      v[i] = q[i] = 1;
      return 1;
    }
  }
  return 0;
}

#ifdef WORDLE_WASM
/* JS writes "<allowed words>\0<possible words>\0" here, then calls
 * load_words_buf(). Afterwards the buffer doubles as scratch space. */
char io_buf[131072];

char *get_io_buf(void) { return io_buf; }

/* Calls fn on each whitespace-separated 5-letter token; returns past the NUL. */
static const char *each_word(const char *p, int (*fn)(const char *), int *count) {
  char word[6];
  while (*p) {
    while (*p == ' ' || *p == '\n' || *p == '\r' || *p == '\t') p++;
    int n = 0;
    while (*p && *p != ' ' && *p != '\n' && *p != '\r' && *p != '\t') {
      if (n < 5) word[n] = *p;
      n++, p++;
    }
    if (n >= 5) {
      word[5] = '\0';
      *count += fn(word);
    }
  }
  return p + 1;
}

static int add_allowed_counted(const char *word) {
  add_allowed(word);
  return 1;
}

int load_words_buf(void) {
  int allowed = 0, possible = 0;
  reset_words();
  const char *p = each_word(io_buf, add_allowed_counted, &allowed);
  each_word(p, mark_possible, &possible);
  return N;
}
#else
int load_words(const char *allowed_path, const char *possible_path) {
  reset_words();
  
  FILE *f = fopen(allowed_path, "r");
  if (!f) {
    printf("C Error: Could not open allowed_words at %s\n", allowed_path);
    return 0;
  }
  char word_buf[16];
  while (fscanf(f, "%15s", word_buf) == 1) {
    // Basic trimming and length safety
    word_buf[5] = '\0';
    add_allowed(word_buf);
  }
  fclose(f);
  printf("C Info: Loaded %d allowed words\n", N);
  
  f = fopen(possible_path, "r");
  if (!f) {
    printf("C Error: Could not open possible_words at %s\n", possible_path);
    return 0;
  }
  int p_count = 0;
  while (fscanf(f, "%15s", word_buf) == 1) {
    word_buf[5] = '\0';
    p_count += mark_possible(word_buf);
  }
  fclose(f);
  printf("C Info: Loaded %d possible words mapped to allowed list\n", p_count);
  return N;
}
#endif

int filter_possible(int guess_idx, int target) {
  int act = 0;
  for (int i = 0; i < N; i++) {
    if (v[i]) {
      if (cmp(w[guess_idx], w[i]) != target)
        v[i] = 0;
      else
        act++;
    }
  }
  return act;
}

int calculate_best_move(int *out_score) {
  int b_score = 2e9, b_idx = 0;
  for (int i = 0; i < N; i++) {
    int c[243] = {0}, score = 0;
    for (int j = 0; j < N; j++) {
      if (v[j]) {
        c[cmp(w[i], w[j])]++;
      }
    }
    for (int k = 0; k < 243; k++) {
      if (c[k]) {
        score += L[c[k]];
      }
    }
    // Priority modifiers: heavily favor words that are potential answers
    // Entropy is ~3,000,000. We use a 200k/50k bonus to ensure it shifts the top tiers.
    score -= (v[i] ? 200000 : 0) + (q[i] ? 50000 : 0);
    
    if (score < b_score) {
      b_score = score;
      b_idx = i;
    }
  }
  *out_score = b_score;
  return b_idx;
}

int get_word_score(int idx) {
    int c[243] = {0}, score = 0;
    for (int j = 0; j < N; j++) {
      if (v[j]) {
        c[cmp(w[idx], w[j])]++;
      }
    }
    for (int k = 0; k < 243; k++) {
      if (c[k]) {
        score += L[c[k]];
      }
    }
    score -= (v[idx] ? 200000 : 0) + (q[idx] ? 50000 : 0);
    return score;
}

const char* get_word(int idx) {
  return w[idx];
}

int get_is_possible(int idx) {
  return v[idx];
}

int get_is_answer(int idx) {
    return q[idx];
}
