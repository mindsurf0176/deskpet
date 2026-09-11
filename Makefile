PREFIX ?= $(CURDIR)
BINDIR ?= $(HOME)/.local/bin
BUILD := $(PREFIX)/.build/release/deskpet
BIN := $(BINDIR)/deskpet
PLIST := $(HOME)/Library/LaunchAgents/ai.deskpet.plist
PLUGIN := $(HOME)/.config/opencode/plugins/deskpet.ts
LABEL := ai.deskpet
OLD_LABEL := ai.minseo.deskpet
UID := $(shell id -u)
LOG := $(HOME)/.codex/pets/deskpet.log
HOOK_SRC := $(PREFIX)/plugin/codex-hook.py
HOOK_INSTALL := $(PREFIX)/scripts/install-codex-hook.py

.PHONY: build install run stop unload uninstall plugin hook

build:
	swift build -c release --package-path $(PREFIX)

plugin:
	mkdir -p $(dir $(PLUGIN))
	cp $(PREFIX)/plugin/deskpet.ts $(PLUGIN)

hook:
	python3 $(HOOK_INSTALL) $(HOOK_SRC)

$(BIN): build
	mkdir -p $(BINDIR)
	cp $(BUILD) $(BIN)

$(PLIST): $(BIN)
	mkdir -p $(HOME)/Library/LaunchAgents $(HOME)/.codex/pets
	printf '%s\n' \
	'<?xml version="1.0" encoding="UTF-8"?>' \
	'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	'<plist version="1.0"><dict>' \
	'<key>Label</key><string>$(LABEL)</string>' \
	'<key>ProgramArguments</key><array><string>$(BIN)</string></array>' \
	'<key>RunAtLoad</key><true/>' \
	'<key>KeepAlive</key><true/>' \
	'<key>WorkingDirectory</key><string>$(HOME)</string>' \
	'<key>StandardOutPath</key><string>$(LOG)</string>' \
	'<key>StandardErrorPath</key><string>$(LOG)</string>' \
	'</dict></plist>' > $(PLIST)

install: $(BIN) plugin hook $(PLIST)
	launchctl bootout gui/$(UID)/$(OLD_LABEL) 2>/dev/null || true
	rm -f $(HOME)/Library/LaunchAgents/$(OLD_LABEL).plist
	launchctl bootout gui/$(UID)/$(LABEL) 2>/dev/null || true
	sleep 0.4
	launchctl bootstrap gui/$(UID) $(PLIST) 2>/dev/null || true
	launchctl enable gui/$(UID)/$(LABEL)
	launchctl kickstart -k gui/$(UID)/$(LABEL)

run: build
	$(BUILD)

stop:
	launchctl bootout gui/$(UID)/$(LABEL) 2>/dev/null || true
	launchctl bootout gui/$(UID)/$(OLD_LABEL) 2>/dev/null || true
	pkill -x deskpet 2>/dev/null || true

unload: stop
	rm -f $(PLIST) $(HOME)/Library/LaunchAgents/$(OLD_LABEL).plist

uninstall: unload
	rm -f $(BIN) $(PLUGIN)
	python3 $(HOOK_INSTALL) --uninstall
