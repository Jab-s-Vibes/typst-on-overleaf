# Typst on Overleaf

Compile a Typst document inside Overleaf's sandbox — and get working
click-to-source navigation in the Overleaf PDF viewer.

**This is an unsupported hack.** It relies on details of Overleaf's compile
sandbox (seccomp profile, container image, viewer) that can change at any
time. Tested on overleaf.com, 2026-08.

## What you get

- `main.typ.txt` (the whole document: wrapper + body, Springer Nature
  style) compiles to `output.pdf` via a vendored Typst binary.
- Every text run maps to its exact source line: double-click any word in
  the PDF → jumps to it in the editor (forward and reverse search work).
- The same sources convert to real LaTeX via pandoc if your venue wants a
  `.tex` submission (see `typst2latex.lua` in the full workflow repo).

## Files

| file | purpose |
|---|---|
| `main.typ.txt` (named `.txt` so Overleaf's editor opens it) | the whole document: title block + body |
| `latexmkrc` | overrides the pdflatex step; runs typst + synctex generator |
| `main.tex` | stub main document (Overleaf needs one; never compiled) |
| `typst-x86_64-unknown-linux-gnu.tar.gz` | typst 0.15.1 built for glibc 2.39, patched with `query --map` |
| `pollshim.so` | LD_PRELOAD shim — see "Why the shim" below |
| `synctex-gen.txt` | perl script: `typst query --map` → `output.synctex.gz` |
| `typst-packages/` | vendored `@preview` packages (the sandbox has no network) |

## Use

1. Import this directory as an Overleaf project (zip it, or push it as a
   git repo to your Overleaf project).
2. Edit `main.typ.txt`.
3. Compile. The PDF appears; click-to-source works.
4. If you add `@preview` packages, vendor them under `typst-packages/`
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
and emits one record per text run: `path|line|col|page|x|y|w|h`). To
rebuild:

```sh
git clone --branch v0.15.1 https://github.com/typst/typst
cd typst
# apply the --map patch (see the blog post / synctex-gen.txt for the output format)
cargo build --release --bin typst
tar -czf typst-x86_64-unknown-linux-gnu.tar.gz typst-x86_64-unknown-linux-gnu
```

## Vendoring a new package

```sh
# locally:
typst compile --package-path ./typst-packages main.typ.txt
# then copy the resolved package dir from ~/.cache/typst/packages/preview/<name>/<version>
# into typst-packages/preview/<name>/<version>/ and commit it
```

## Exporting to LaTeX

Raw-LaTeX fragments (like the wrapper's `\begin{abstract}` block) are
passed through by pandoc's typst reader:

```sh
pandoc -f typst -t latex --lua-filter=typst2latex.lua main.typ.txt -o main.tex
```

## Limitations

- Section/paragraph-level precision matches LaTeX's SyncTeX (it is
  line-level anyway).
- The vendored template's own text (e.g. the "Abstract" label) maps to
  the template file, not your sources — filtered out of the synctex.
- Overleaf could change the sandbox profile, container image, or viewer
  at any time. Pin everything and re-test after Overleaf updates.
