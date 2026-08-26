---
name: tdd-process
description: Test-driven development (TDD) process for implementing features — happy-path test first, implementation, edge case tests, unit tests, and full suite run
---

# Development Process: Test-Driven Development

Once the implementation plan is approved, follow a strict test-driven development (TDD) approach.

## Step 1: Write the Happy Path Integration Test

Begin coding by writing a complete integration test that:

- Covers the core intended behavior
- Uses realistic mocks/stubs for AWS (Moto or custom harness)
- Uses FastAPI TestClient or Chalice local testing
- Represents the most common successful flow

This test should **fail initially** since the feature doesn't exist yet.

### Example Integration Test Structure

```python
def test_user_sync_endpoint_happy_path():
    """Test successful user sync endpoint request."""
    # Arrange: set up test data and mocks
    # Act: make the request to the endpoint
    # Assert: verify the response and side effects
```

---

## Step 2: Implement the Feature

Write production code to satisfy the happy-path integration test.

- Keep implementation focused on passing the test
- Avoid over-engineering at this stage
- Code should be clean but doesn't need to be perfect

**The happy-path test should now pass.**

---

## Step 3: Add Additional Integration Tests

Create more tests covering failure scenarios and edge cases:

- Invalid input handling
- AWS service failures or errors
- Timeout or retry scenarios
- Cross-service edge cases
- Error responses and status codes
- State mutations and side effects

Each test should:

- Have a clear name describing the scenario
- Test one specific behavior
- Be isolated and repeatable

---

## Step 4: Add Unit Tests (When Appropriate)

Only add unit tests when:

- Logic is complex and benefits from isolation
- Pure functions or utilities require targeted testing
- Individual functions need edge case coverage

Most integration tests should be sufficient for application code.

---

## Step 5: Run Full Test Suite

Execute all tests to ensure nothing broke:

```bash
# Activate virtual environment first
source .venv/bin/activate

# Run all tests
pytest

# Or with coverage
pytest --cov=src
```

**All tests must pass** before proceeding to commit and PR.

Verify:

- ✓ Integration tests pass
- ✓ Unit tests pass
- ✓ No regressions in existing tests
- ✓ Code follows project style (optional linters/type checks)

---

## Implementation Checklist

- [ ] Happy-path integration test written and passing
- [ ] Feature implementation complete
- [ ] Additional edge case tests written and passing
- [ ] Unit tests added (if needed)
- [ ] Full test suite passes with no regressions
- [ ] Code is clean and readable
- [ ] Ready for commit and PR
