# GetStream Ruby SDK Makefile

.PHONY: help install test test-unit test-integration lint format clean setup

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
		cp .env.example .env; \
		echo "Please edit .env file with your GetStream credentials"; \
	fi
	bundle install
	@echo "Setup complete! Don't forget to configure your .env file."

# Testing
test: test-unit ## Run unit tests only

test-unit: ## Run unit tests (excluding integration tests)
	bundle exec rspec spec --exclude-pattern "spec/integration/**/*_spec.rb"

test-integration: ## Run integration tests only
	bundle exec rspec spec/integration/

test-all: ## Run all tests (unit + integration)
	bundle exec rspec spec/

# Code Quality
lint: ## Run RuboCop linter
	bundle exec rubocop

format: ## Format code with RuboCop
	bundle exec rubocop -A

format-check: ## Check if code is properly formatted (CI-friendly)
	bundle exec rubocop

security: ## Run security audit
	bundle exec bundler-audit check --update

# Utilities
clean: ## Clean up generated files
	rm -rf coverage/
	rm -rf pkg/
	rm -rf tmp/
	rm -rf vendor/bundle/

console: ## Start IRB console with SDK loaded
	bundle exec irb -r ./lib/getstream_ruby

version: ## Show current version
	@ruby -e "require './lib/getstream_ruby/version'; puts GetStreamRuby::VERSION"

# Version management
patch: ## Bump patch version (0.0.1 -> 0.0.2)
	@./scripts/version-bump.sh patch

minor: ## Bump minor version (0.0.1 -> 0.1.0)
	@./scripts/version-bump.sh minor

major: ## Bump major version (0.0.1 -> 1.0.0)
	@./scripts/version-bump.sh major

# Development helpers
dev-setup: setup ## Complete development setup
	@echo "Development setup complete!"

dev-check: lint test ## Run all development checks