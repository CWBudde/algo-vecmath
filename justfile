# Default recipe - show available commands
default:
    @just --list

# Build all packages
build:
    go build ./...

# Run all tests
test:
    go test -v -race -count=1 ./...

# Run tests without assembly backends
test-purego:
    go test -v -count=1 -tags purego ./...

# Run linters
lint:
    golangci-lint run --timeout=2m ./...

# Format all code
fmt:
    gofumpt -l -w .

# Run all checks
check: test test-purego lint check-deps

# Are all github.com/cwbudde/* dependencies at their latest tags?
check-deps:
    ./scripts/release-guard.sh deps

# How much work is sitting on main past the latest tag?
check-unreleased:
    ./scripts/release-guard.sh unreleased

# Check every release precondition for VERSION without tagging anything.
release-check VERSION:
    ./scripts/release-guard.sh gate {{VERSION}}

# Tag VERSION: run the full gate, then create and push the annotated tag.
# Refuses on a dirty tree, stale siblings, a missing CHANGELOG section, or an
# incompatible API change the version does not signal. See AGENTS.md.
tag-release VERSION:
    ./scripts/release-guard.sh tag {{VERSION}}
