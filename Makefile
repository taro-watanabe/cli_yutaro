.PHONY: deps rootfs site dev clean lint fmt check

BUILD_DIR := build
V86_RELEASE := https://github.com/copy/v86/releases/download/latest
V86_RAW := https://raw.githubusercontent.com/copy/v86/master
XTERM_CDN := https://cdn.jsdelivr.net/npm/@xterm/xterm@6.0.0

deps: $(BUILD_DIR)/libv86.js $(BUILD_DIR)/v86.wasm $(BUILD_DIR)/seabios.bin $(BUILD_DIR)/vgabios.bin $(BUILD_DIR)/xterm.js $(BUILD_DIR)/xterm.css

$(BUILD_DIR)/libv86.js:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(V86_RELEASE)/libv86.js

$(BUILD_DIR)/v86.wasm:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(V86_RELEASE)/v86.wasm

$(BUILD_DIR)/seabios.bin:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(V86_RAW)/bios/seabios.bin

$(BUILD_DIR)/vgabios.bin:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(V86_RAW)/bios/vgabios.bin

$(BUILD_DIR)/xterm.js:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(XTERM_CDN)/lib/xterm.js

$(BUILD_DIR)/xterm.css:
	mkdir -p $(BUILD_DIR)
	curl -L -o $@ $(XTERM_CDN)/css/xterm.css

rootfs: deps
	bash scripts/build-rootfs.sh

site: rootfs
	npm install
	npx tsc
	cp index.html $(BUILD_DIR)/
	cp ascii-loading.txt $(BUILD_DIR)/
	cp -r css $(BUILD_DIR)/

dev: site
	cd $(BUILD_DIR) && python3 -m http.server 8000

lint:
	npx oxlint js/

fmt:
	npx oxfmt --write js/

check:
	npx tsc --noEmit
	npx oxlint js/
	npx oxfmt --check js/

clean:
	rm -rf $(BUILD_DIR)
	rm -rf node_modules
