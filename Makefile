# Build or fetch the two binary blobs (typst tarball, pollshim.so).
#
#   make blobs        download both from the GitHub Release (fast path)
#   make build-blobs  build both from source (needs cargo, gcc)
#   make clean        remove downloaded/built blobs
#
# The Overleaf project needs both files present: latexmkrc extracts
# the tarball and LD_PRELOADs pollshim.so.

RELEASE_URL := https://github.com/Jab-s-Vibes/typst-on-overleaf/releases/latest/download
TARBALL     := typst-x86_64-unknown-linux-gnu.tar.gz
TYPST_TAG   := v0.15.1

.PHONY: blobs build-blobs clean

blobs:
	curl -fL $(RELEASE_URL)/$(TARBALL) -o $(TARBALL)
	curl -fL $(RELEASE_URL)/pollshim.so -o pollshim.so

build-blobs: pollshim.so $(TARBALL)

pollshim.so: pollshim.c
	$(CC) -shared -fPIC -O2 $< -o $@

$(TARBALL):
	rm -rf /tmp/typst-build typst-bin
	git clone --depth 1 --branch $(TYPST_TAG) https://github.com/typst/typst /tmp/typst-build
	cd /tmp/typst-build && git apply $(CURDIR)/typst-query-map.patch
	cd /tmp/typst-build && cargo build --release --bin typst
	mkdir -p typst-bin/typst-x86_64-unknown-linux-gnu
	cp /tmp/typst-build/target/release/typst typst-bin/typst-x86_64-unknown-linux-gnu/
	tar -czf $@ -C typst-bin typst-x86_64-unknown-linux-gnu
	rm -rf /tmp/typst-build typst-bin

clean:
	rm -f $(TARBALL) pollshim.so
