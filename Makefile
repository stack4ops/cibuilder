.PHONY: test test-verbose test-count help

help:
	@echo "Available targets:"
	@echo "  make test         - Run all Bats tests"
	@echo "  make test-verbose - Run tests with verbose output"
	@echo "  make test-count   - Show test statistics"
	@echo "  make help         - Show this help message"

test:
	bats tests/*.bats

test-verbose:
	bats -t tests/*.bats

test-count:
	@echo Total tests: && bats tests/*.bats 2>&1 | grep "^1\.\." | cut -d. -f2
	@echo Passing: && bats tests/*.bats 2>&1 | grep "^ok" | wc -l
	@echo Failing: && bats tests/*.bats 2>&1 | grep "^not ok" | wc -l
