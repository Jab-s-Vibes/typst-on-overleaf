# Typst on Overleaf

Compile a Typst document inside Overleaf's sandbox — and get working
click-to-source navigation in the Overleaf PDF viewer.

Full writeup: <https://jab-s-vibes.github.io/typst-on-overleaf.html>

**This is an unsupported hack.** It relies on details of Overleaf's compile
sandbox (seccomp profile, container image, viewer) that can change at any
time. Tested on overleaf.com, 2026-08.

## What you get

- `main.typ.tex` (the whole document: wrapper + body, Springer Nature
  style) compiles to `output.pdf` via a vendored Typst binary.
- Every text run maps to its exact source line: double-click any word in
  the PDF → jumps to it in the editor (forward and reverse search work).
- The same sources convert to real LaTeX via pandoc if your venue wants a
  `.tex` submission (see `typst2latex.lua` in the full workflow repo).

## Files

| file | purpose |
|---|---|
| `main.typ.tex` (named `.txt` so Overleaf's editor opens it) | the whole document: title block + body |
| `latexmkrc` | overrides the pdflatex step; runs typst + synctex generator |
| `main.tex` | stub main document (Overleaf needs one; never compiled) |
| `typst-query-map.patch` | the `--map` patch, applies to typst v0.15.1 (`git apply` from the typst tree root) |
| `pollshim.c` | source of `pollshim.so` — see "Why the shim" below |
| `synctex-gen.txt` | perl script: `typst query --map` → `output.synctex.gz` |
| `Makefile` | `make blobs` (download) or `make build-blobs` (build) the two binary blobs |
| `typst-packages/` | vendored `@preview` packages (currently none; see "Vendoring a new package") |

## Use

1. Get the two blobs — `typst-x86_64-unknown-linux-gnu.tar.gz` and
   `pollshim.so` — from the [GitHub Release](https://github.com/Jab-s-Vibes/typst-on-overleaf/releases/latest)
   (`make blobs`), or build them yourself (`make build-blobs`).
2. Import this directory as an Overleaf project (zip it, or push it as a
   git repo to your Overleaf project).
3. Edit `main.typ.tex`.
4. Compile. The PDF appears; click-to-source works.
5. If you add `@preview` packages, vendor them under `typst-packages/`
   (see below) — the sandbox cannot download them.

### Settings

- PDF Viewer must be **Overleaf** (not *Browser*): Settings → Editor →
  PDF Viewer → Overleaf. The Browser viewer has no source navigation.
- Compiler: **pdfLaTeX** is fine (it is never actually run).
- Free-tier compile timeout is 10 s; the single-threaded compile takes
  ~2 s.

## Why the shim

Overleaf's compile sandbox uses a default-deny seccomp profile
(`overleaf/clsi/seccomp/clsi-profile.json`). The `poll(2)` syscall is not
allowed, and Rust's standard library aborts the process on the resulting
`EPERM` (in `sanitize_standard_fds`, every unexpected errno from the
startup poll of fds 0/1/2 calls `libc::abort()`).

`pollshim.so` makes `poll(2)` return `EINVAL` instead — one of the errnos
Rust std tolerates — so it falls back to `fcntl(F_GETFD)`, which *is*
allowed. `poll` is called through libc, so `LD_PRELOAD` can interpose it.
(Blocked `getrandom` is handled by Rust std itself: it falls back to
`/dev/urandom` on EPERM.)

The typst binary is glibc-linked (LD_PRELOAD needs dynamic linking) and
built on Ubuntu 24.04 to match the sandbox's glibc 2.39.

## Updating the typst binary

The binary is patched (added `typst query --map`, which walks the layout
and emits one record per text run: `path|line|col|page|x|y|w|h`). The
patch ships as `typst-query-map.patch` (applies to typst v0.15.1). To
rebuild:

```sh
git clone --branch v0.15.1 https://github.com/typst/typst
cd typst
git apply /path/to/typst-query-map.patch
cargo build --release --bin typst
# build must be glibc-linked, matching the sandbox glibc (2.39);
# keep symbols (`strip=false`) or the LD_PRELOAD shim won't interpose.
tar -czf typst-x86_64-unknown-linux-gnu.tar.gz typst-x86_64-unknown-linux-gnu
```

## Vendoring a new package

```sh
# locally:
typst compile --package-path ./typst-packages main.typ.tex
# then copy the resolved package dir from ~/.cache/typst/packages/preview/<name>/<version>
# into typst-packages/preview/<name>/<version>/ and commit it
```

## Exporting to LaTeX

Raw-LaTeX fragments (like the wrapper's `\begin{abstract}` block) are
passed through by pandoc's typst reader:

```sh
pandoc -f typst -t latex --lua-filter=typst2latex.lua main.typ.tex -o main.tex
```

## Limitations

- Section/paragraph-level precision matches LaTeX's SyncTeX (it is
  line-level anyway).
- The vendored template's own text (e.g. the "Abstract" label) maps to
  the template file, not your sources — filtered out of the synctex.
- Overleaf could change the sandbox profile, container image, or viewer
  at any time. Pin everything and re-test after Overleaf updates.

---

*AI-generated with pi / deepseek-v4-flash. Content may be wrong; verify before relying on it.*
