.PHONY: run

WORKSPACE_DIR := /workspace

test_parser:
	@echo "Testing parser implementation..."
	python3 parsing.py \
		stdout.txt \
		stderr.txt \
		test_results.json
	@echo "Results saved to test_results.json"
