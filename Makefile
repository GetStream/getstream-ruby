# GetStream Ruby SDK Makefile

.PHONY: help install test test-unit test-integration test-all lint format clean setup release-major release-minor release-patch

# Default target
help: ## Show this help message
	@echo "GetStream Ruby SDK - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Setup and Installation
install: ## Install dependencies
	bundle install

setup: ## Setup development environment
	@echo "Setting up development environment..."
	@if [ ! -f .env ]; then \
		echo "Creating .env file from .env.example..."; \
		cp env.example .env; \
		echo "Please edit .env file with your GetStream credentials"; \
	fi
	bundle install
	@echo "Setup complete! Don't forget to configure your .env file."

# Testing
test: test-unit ## Run unit tests only

test-unit: ## Run unit tests (excluding integration tests)
	bundle exec rspec spec --exclude-pattern "spec/integration/**/*_spec.rb"

test-integration: ## Run integration tests only
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Please run 'make setup' first."; \
		exit 1; \
	fi
	bundle exec rspec spec/integration/

test-all: ## Run all tests (unit + integration)
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Please run 'make setup' first."; \
		exit 1; \
	fi
	bundle exec rspec spec/

coverage: ## Run tests with coverage
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Please run 'make setup' first."; \
		exit 1; \
	fi
	COVERAGE=true bundle exec rspec spec/ --format documentation

# Code Quality
lint: ## Run RuboCop linter
	bundle exec rubocop

format: ## Format code with RuboCop
	bundle exec rubocop -A

format-check: ## Check if code is properly formatted (CI-friendly)
	bundle exec rubocop --format json

format-fix: ## Auto-fix all RuboCop issues
	bundle exec rubocop -A --format simple

format-diff: ## Show formatting differences
	bundle exec rubocop --format simple

format-todo: ## Show RuboCop TODOs
	bundle exec rubocop --format todo

format-progress: ## Show RuboCop progress
	bundle exec rubocop --format progress

format-offenses: ## Show only RuboCop offenses
	bundle exec rubocop --format offenses

format-json: ## Output RuboCop results as JSON
	bundle exec rubocop --format json

format-html: ## Generate HTML RuboCop report
	bundle exec rubocop --format html -o rubocop-report.html

format-xml: ## Generate XML RuboCop report
	bundle exec rubocop --format xml -o rubocop-report.xml

# Security
security: ## Run security audit
	bundle audit

security-update: ## Update vulnerable gems
	bundle audit --update

# Documentation
docs: ## Generate documentation
	bundle exec yard doc

docs-server: ## Start documentation server
	bundle exec yard server --reload

# Development
dev-setup: ## Complete development setup
	@echo "Setting up development environment..."
	@make install
	@make setup
	@make format-fix
	@echo "Development environment ready!"

dev-check: ## Run all development checks
	@echo "Running development checks..."
	@make format-check
	@make security
	@make test
	@echo "All checks passed!"

# Release helpers
version: ## Show current version
	@ruby -e "require './lib/getstream_ruby/version'; puts GetStreamRuby::VERSION"

version-patch: ## Bump patch version
	@ruby -e "require_relative 'lib/getstream_ruby/version'; puts GetStreamRuby::VERSION.gsub(/\.(\d+)$/, '.\1')"

version-minor: ## Bump minor version
	@ruby -e "require_relative 'lib/getstream_ruby/version'; v = GetStreamRuby::VERSION.split('.'); v[1] = (v[1].to_i + 1).to_s; v[2] = '0'; puts v.join('.')"

version-major: ## Bump major version
	@ruby -e "require_relative 'lib/getstream_ruby/version'; v = GetStreamRuby::VERSION.split('.'); v[0] = (v[0].to_i + 1).to_s; v[1] = '0'; v[2] = '0'; puts v.join('.')"

# Cleanup
clean: ## Clean up generated files
	rm -rf coverage/
	rm -rf tmp/
	rm -rf .rspec_status
	find . -name "*.gem" -delete
	find . -name "*.rbc" -delete

# Release Management
release-major: ## Release a new major version
	@echo "Releasing major version..."
	@if git log --oneline -1 | grep -q "major"; then \
		bundle exec rake release; \
	else \
		echo "Error: Last commit must contain 'major' to trigger major release"; \
		exit 1; \
	fi

release-minor: ## Release a new minor version
	@echo "Releasing minor version..."
	@if git log --oneline -1 | grep -q "minor"; then \
		bundle exec rake release; \
	else \
		echo "Error: Last commit must contain 'minor' to trigger minor release"; \
		exit 1; \
	fi

release-patch: ## Release a new patch version
	@echo "Releasing patch version..."
	@if git log --oneline -1 | grep -q "patch"; then \
		bundle exec rake release; \
	else \
		echo "Error: Last commit must contain 'patch' to trigger patch release"; \
		exit 1; \
	fi

# Development
console: ## Start IRB console with SDK loaded
	bundle exec irb -r ./lib/getstream_ruby

# CI/CD helpers
ci-test: ## Run tests for CI (with proper exit codes)
	@echo "Running CI tests..."
	bundle exec rspec spec/ --format progress --fail-fast

ci-integration: ## Run integration tests for CI
	@echo "Running integration tests for CI..."
	bundle exec rspec spec/integration/ --format progress --fail-fast

# Documentation
docs: ## Generate documentation
	bundle exec yard doc

# Security
security: ## Run security audit
	bundle exec bundle audit

# Dependencies
update-deps: ## Update dependencies
	bundle update

# Version management
version: ## Show current version
	@ruby -e "require './lib/getstream_ruby/version'; puts GetStreamRuby::VERSION"

# Check if we're in CI
is-ci:
	@if [ -n "$$CI" ] || [ -n "$$GITHUB_ACTIONS" ]; then \
		echo "true"; \
	else \
		echo "false"; \
	fi
