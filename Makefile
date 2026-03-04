SHELL := /bin/bash

SOURCE_REPO ?= /home/cheny0y/git/mas-benchmark
SOURCES_FILE ?= config/source_repos.txt
MANIFEST ?= config/assets_manifest.txt
SYNC_SCRIPT ?= scripts/sync_assets.sh

.PHONY: sync clean-assets

sync:
	@bash $(SYNC_SCRIPT) --source "$(SOURCE_REPO)" --sources-file "$(SOURCES_FILE)" --manifest "$(MANIFEST)" --dest "."

clean-assets:
	@rm -rf static/images/*
