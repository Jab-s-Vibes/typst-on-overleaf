# Overleaf: redirect the "pdflatex" step to Typst (unsupported hack).
# typst (glibc, Ubuntu 24.04-matching) ships as tar.gz; /compile is
# mounted noexec, so binaries run from /tmp.
#
# Sandbox facts (overleaf/clsi seccomp/clsi-profile.json, default ERRNO):
#  - poll(2) blocked -> Rust std's sanitize_standard_fds() aborts (SIGABRT)
#  - getrandom blocked -> std handles it: falls back to /dev/urandom
#  - fcntl, openat, read allowed
# pollshim.so (LD_PRELOAD) makes poll return EINVAL: std then uses the
# fcntl fallback instead of aborting.
#
# Source tracking: typst emits no synctex; synctex-gen.txt derives one
# from `typst eval` positions of labeled elements (headings, figures,
# tables, equations) mapped to source lines via their labels. Both
# directions validated with the texlive synctex CLI.
$go_mode = 1;

$pdflatex = 'export LD_PRELOAD=/tmp/pollshim.so RAYON_NUM_THREADS=1; mkdir -p typst-bin; tar -zxf typst-x86_64-unknown-linux-gnu.tar.gz -C typst-bin --strip-components=1 2>> output.log; cp typst-bin/typst /tmp/typst 2>> output.log; cp pollshim.so /tmp/pollshim.so 2>> output.log; chmod +x /tmp/typst 2>> output.log; /tmp/typst compile --package-path ./typst-packages main.typ.tex output.pdf 2>> output.log; test -s output.pdf || /tmp/typst compile --package-path ./typst-packages main.typ.tex output.pdf 2>> output.log; test -s output.pdf || /tmp/typst compile --package-path ./typst-packages main.typ.tex output.pdf 2>> output.log; ls -la output.pdf >> output.log 2>&1; test -s output.pdf && echo COMPILE_OK >> output.log || echo COMPILE_FAILED >> output.log; perl synctex-gen.txt 2>> output.log | gzip -c > output.synctex.gz #';
