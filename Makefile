PREFIX ?= $(CURDIR)
BINDIR ?= $(HOME)/.local/bin
BUILD := $(PREFIX)/.build/release/deskpet
APPBUILD := $(PREFIX)/.build/DeskPet.app
APPROOT := $(shell [ -w /Applications ] && echo /Applications || echo $(HOME)/Applications)
APPDIR := $(APPROOT)/DeskPet.app
APPBIN := $(APPDIR)/Contents/MacOS/deskpet
BIN := $(BINDIR)/deskpet
PLUGIN := $(HOME)/.config/opencode/plugins/deskpet.ts
LABEL := ai.deskpet
OLD_LABEL := ai.minseo.deskpet
UID := $(shell id -u)
HOOK_SRC := $(PREFIX)/plugin/codex-hook.py
HOOK_INSTALL := $(PREFIX)/scripts/install-codex-hook.py

.PHONY: build app install run stop unload uninstall plugin hook

build:
	swift build -c release --package-path $(PREFIX)

app: build
	chmod +x $(PREFIX)/scripts/make-app.sh $(PREFIX)/scripts/make-icns.swift
	$(PREFIX)/scripts/make-app.sh $(BUILD) $(APPBUILD)

plugin:
	mkdir -p $(dir $(PLUGIN))
	cp $(PREFIX)/plugin/deskpet.ts $(PLUGIN)

hook:
	python3 $(HOOK_INSTALL) $(HOOK_SRC)

# Retire the LaunchAgent from older installs. Startup now lives in the app,
# under Open at Login, so only one mechanism controls it.
unload:
	launchctl bootout gui/$(UID)/$(LABEL) 2>/dev/null || true
	launchctl bootout gui/$(UID)/$(OLD_LABEL) 2>/dev/null || true
	rm -f $(HOME)/Library/LaunchAgents/$(LABEL).plist $(HOME)/Library/LaunchAgents/$(OLD_LABEL).plist

$(APPDIR): app unload
	pkill -x deskpet 2>/dev/null || true
	sleep 0.4
	mkdir -p $(APPROOT)
	rm -rf $(APPDIR)
	cp -R $(APPBUILD) $(APPDIR)
	[ "$(APPDIR)" = "$(HOME)/Applications/DeskPet.app" ] || rm -rf $(HOME)/Applications/DeskPet.app

$(BIN): $(APPDIR)
	mkdir -p $(BINDIR)
	ln -sfn $(APPBIN) $(BIN)

install: $(APPDIR) $(BIN) plugin hook
	mkdir -p $(HOME)/.codex/pets
	open "$(APPDIR)"
	@echo "Installed to $(APPDIR)."
	@echo "Turn on Open at Login in the menu bar paw to start DeskPet with macOS."

run: build
	$(BUILD)

stop:
	pkill -x deskpet 2>/dev/null || true

uninstall: stop unload
	rm -f $(BIN) $(PLUGIN)
	rm -rf $(APPDIR) $(HOME)/Applications/DeskPet.app
	python3 $(HOOK_INSTALL) --uninstall
	@echo "If Open at Login was on, remove DeskPet in System Settings > General > Login Items."
