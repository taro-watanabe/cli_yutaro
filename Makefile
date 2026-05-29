.PHONY: deps rootfs site dev clean lint fmt check

BUILD_DIR := build
V86_RELEASE := https://github.com/copy/v86/releases/download/latest
V86_RAW := https://raw.githubusercontent.com/copy/v86/master

deps: $(BUILD_DIR)/libv86.js $(BUILD_DIR)/v86.wasm $(BUILD_DIR)/seabios.bin $(BUILD_DIR)/vgabios.bin

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

rootfs:
	bash scripts/build-rootfs.sh

site: deps rootfs
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
