SHELL := /usr/bin/env bash

SCRIPTS := \
	scripts/display-extend.sh \
	scripts/start-monitor.sh \
	scripts/stop-monitor.sh \
	universal_installer.sh \
	installer/universal_installer.sh \
	display_extend_package.sh \
	installer/display_extend_package.sh \
	install.sh

.PHONY: test lint format package clean ci

test:
	bash tests/smoke.sh

lint:
	shellcheck $(SCRIPTS) tests/smoke.sh

format:
	shfmt -w $(SCRIPTS) tests/smoke.sh

package:
	bash display_extend_package.sh

clean:
	rm -rf build
	rm -rf linux-display-extend-1.0

ci: lint test
