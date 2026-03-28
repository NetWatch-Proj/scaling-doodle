# Scaling Doodle

[![CI](https://github.com/NetWatch-Proj/scaling-doodle/actions/workflows/ci.yml/badge.svg)](https://github.com/NetWatch-Proj/scaling-doodle/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/NetWatch-Proj/scaling-doodle/graph/badge.svg?token=SH9K8B4ZVF)](https://codecov.io/gh/NetWatch-Proj/scaling-doodle)

This is a super secret product that's in stealth mode.

## Testing

**Unit tests** (run automatically on PRs):
```bash
cd apps/platform
mix test
```

**Integration tests** (requires Kubernetes, run manually):
```bash
# Setup kind cluster
kind create cluster --name openclaw-platform

# Run tests
cd apps/platform
mix test --include integration
```

Integration tests can also be run via GitHub Actions → "Integration Tests" workflow (manual trigger).
