---
name: testing-requirements
description: Pre-implementation testing checklist — activate virtualenv, start infrastructure with make run-spec-infra, and run full pytest suite before writing any new code
---

# Testing Requirements

Before starting any implementation work on a Jira card, complete these pre-implementation steps to ensure a clean environment and prevent regressions.

## Rule: Always Run Full Test Suite First

To guarantee no regressions exist prior to new development:

- Run **all existing tests** before writing any new code
- This verifies the current state of the codebase is healthy
- If tests fail, investigate and resolve failures **before** beginning new work

---

## Step 1: Activate the Virtual Environment

Before running any tests or development commands:

```bash
source .venv/bin/activate
```

**Note**: Use `.venv/bin/activate` (with a dot prefix), not `venv/bin/activate`.

---

## Step 2: Start Project Infrastructure Dependencies

Some tests require running local infrastructure (e.g., databases, queues, LocalStack, etc.).

Start all required Docker services:

```bash
make run-spec-infra
```

This command sets up any necessary services (databases, message queues, etc.) defined in the project's Makefile.

---

## Step 3: Run Full Test Suite

Execute all tests to verify the codebase is in a healthy state:

```bash
# Basic test run
pytest

# With coverage report
pytest --cov=src

# With verbose output
pytest -v
```

All tests must pass before proceeding to development.

---

## Troubleshooting

- **Infrastructure issues**: Ensure `make run-spec-infra` completed successfully
- **Import errors**: Verify virtual environment is activated
- **Failed tests**: Investigate root cause before starting new work (may indicate environment setup issues)
