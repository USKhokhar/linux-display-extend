SHELL := /usr/bin/env bash

SCRIPTS := \
	scripts/lib.sh \
	scripts/display-extend.sh \
	scripts/start-monitor.sh \
	scripts/stop-monitor.sh \
	universal_installer.sh \
	installer/universal_installer.sh \
	display_extend_package.sh \
	installer/display_extend_package.sh \
	install.sh

TESTS := \
	tests/smoke.sh \
	tests/unit.sh \
	tests/integration.sh \
	tests/installer-fallback.sh \
	tests/manual-validation.sh

.PHONY: test unit-test smoke-test integration lint format package clean ci validate checksums

test: unit-test smoke-test

unit-test:
	bash tests/unit.sh

smoke-test:
	bash tests/smoke.sh

integration:
	bash tests/integration.sh

validate:
	bash tests/manual-validation.sh

lint:
	shellcheck $(SCRIPTS) $(TESTS)

format:
	shfmt -w $(SCRIPTS) $(TESTS)

package:
	bash display_extend_package.sh

checksums:
	sha256sum scripts/display-extend.sh scripts/lib.sh VERSION > SHA256SUMS
	@printf 'SHA256SUMS generated:\n'
	@cat SHA256SUMS

clean:
	rm -rf build
	rm -rf linux-display-extend-1.0

ci: lint test
