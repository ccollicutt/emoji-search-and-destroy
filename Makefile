# Makefile for emoji-sad (Emoji Search and Destroy) - PUBLIC VERSION
# Minimal Makefile for building, testing, and CI/CD

.PHONY: help build clean test test-unit test-integration lint deps tidy ci

# Variables
BINARY_NAME=emoji-sad
BIN_DIR=./bin
CMD_DIR=./cmd/emoji-sad
INTEGRATION_TEST_DIR=./tests/integration

# Go related variables
GOCMD=go
GOBUILD=$(GOCMD) build
GOMOD=$(GOCMD) mod
GOTEST=$(GOCMD) test
GOCLEAN=$(GOCMD) clean

# Build flags
BUILD_FLAGS=-v
LDFLAGS=-ldflags "-s -w"

# Version management
VERSION_FILE=internal/version/version.go

# =============================================================================
# HELP
# =============================================================================

help: ## Show this help
	@echo "Emoji Search and Destroy (emoji-sad) - Public Version"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# =============================================================================
# BUILD
# =============================================================================

build: ## Build the emoji-sad CLI binary
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BIN_DIR)
	@if [ -f "$(VERSION_FILE)" ]; then \
		VERSION=$$(grep 'Version = ' $(VERSION_FILE) | sed 's/.*"\(.*\)".*/\1/'); \
		$(GOBUILD) $(BUILD_FLAGS) -trimpath -ldflags "-s -w -X emoji-search-and-destroy/internal/version.Version=$$VERSION" -o $(BIN_DIR)/$(BINARY_NAME) $(CMD_DIR); \
	else \
		$(GOBUILD) $(BUILD_FLAGS) -trimpath $(LDFLAGS) -o $(BIN_DIR)/$(BINARY_NAME) $(CMD_DIR); \
	fi
	@echo "Binary built: $(BIN_DIR)/$(BINARY_NAME)"

clean: ## Clean all build artifacts and temporary files
	@echo "Cleaning..."
	$(GOCLEAN)
	@rm -rf $(BIN_DIR)
	@rm -f coverage.out
	@echo "Clean completed"

# =============================================================================
# TESTING
# =============================================================================

test-unit: ## Run Go unit tests
	@echo "Running unit tests..."
	$(GOTEST) -v ./...

test-integration: build ## Run integration tests (requires binary)
	@echo "Running integration tests..."
	@chmod +x $(INTEGRATION_TEST_DIR)/*.sh
	$(INTEGRATION_TEST_DIR)/run_tests.sh

test: test-unit test-integration ## Run all tests (unit + integration)

# =============================================================================
# STATIC ANALYSIS
# =============================================================================

lint: ## Run basic Go linting (vet and fmt)
	@echo "Running static analysis..."
	@echo "  → go fmt"
	@$(GOCMD) fmt ./...
	@echo "  → go vet"
	@$(GOCMD) vet ./...
	@echo "✓ Static analysis passed"

# =============================================================================
# DEPENDENCIES
# =============================================================================

deps: ## Download dependencies
	@echo "Downloading dependencies..."
	$(GOMOD) download

tidy: ## Tidy up dependencies
	@echo "Tidying up dependencies..."
	$(GOMOD) tidy

# =============================================================================
# CI/CD
# =============================================================================

ci: deps tidy lint test-unit test-integration ## CI workflow (all checks)
	@echo "✓ CI checks passed"

# =============================================================================
# TOOL INSTALLATION
# =============================================================================

install-tools: ## Install required development tools (minimal set for CI/CD)
	@echo "Installing minimal development tools..."
	@echo "  → golangci-lint"
	@if [ -f .golangci-version ]; then \
		GOLANGCI_VERSION=$$(cat .golangci-version); \
	else \
		GOLANGCI_VERSION="v1.61.0"; \
	fi; \
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin $$GOLANGCI_VERSION
	@echo "✓ Development tools installed"

# =============================================================================
# RELEASE MANAGEMENT
# =============================================================================

release: test ## Run tests, then create and push a git tag with the current version
	@if [ ! -f "$(VERSION_FILE)" ]; then \
		echo "Error: $(VERSION_FILE) not found"; \
		exit 1; \
	fi
	@VERSION=$$(grep 'Version = ' $(VERSION_FILE) | sed 's/.*"\(.*\)".*/\1/'); \
	if [ -z "$$VERSION" ]; then \
		echo "Error: Could not extract version from $(VERSION_FILE)"; \
		exit 1; \
	fi; \
	echo "Creating release for version $$VERSION"; \
	if git tag | grep -q "^v$$VERSION$$"; then \
		echo "Error: Tag v$$VERSION already exists"; \
		exit 1; \
	fi; \
	if [ -n "$$(git status --porcelain $(VERSION_FILE))" ]; then \
		echo "Committing version change..."; \
		git add $(VERSION_FILE); \
		git commit -m "Bump version to $$VERSION"; \
		git push origin HEAD; \
	fi; \
	git tag -a "v$$VERSION" -m "Release version $$VERSION"; \
	git push origin "v$$VERSION"; \
	echo "✓ Released version $$VERSION (tag: v$$VERSION)"