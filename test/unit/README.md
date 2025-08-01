# Infrastructure Testing

This directory contains unit tests for the infrastructure shell scripts.

## Testing Framework

We use **BATS (Bash Automated Testing System)** for testing our shell scripts. BATS provides:
- Simple test syntax
- Setup and teardown functions
- Assertion helpers
- Test isolation

## Running Tests

To run the infrastructure tests:

```bash
./test/run_infrastructure_tests.sh
```

Or run directly with bats:

```bash
bats test/unit/test_infrastructure.bats
```

## Test Coverage

The test suite covers:

1. **Error Handling**: Verifies `set -e` and `set -o pipefail` behavior
2. **Variable Initialization**: Tests all script variables are set correctly
3. **Git Operations**: Mocks and validates git fetch, rev-parse, and diff operations
4. **validate_diff Function**: Tests both upstream != head and upstream == head scenarios
5. **Dockerfile Discovery**: Validates file pattern matching and processing
6. **Path Parsing**: Tests base and suite extraction from dockerfile paths
7. **Docker Build**: Validates command construction and execution
8. **File Existence**: Tests handling of missing dockerfiles
9. **Output Messages**: Verifies success and error messaging
10. **Integration**: Full workflow test with all components mocked

## Test Strategy

- **Isolation**: Each test runs in a temporary directory
- **Mocking**: External dependencies (git, docker) are mocked to avoid side effects
- **Edge Cases**: Tests handle empty suites, missing files, and error conditions
- **Integration**: Comprehensive workflow test validates full script execution

## Adding New Tests

When adding new tests:
1. Use descriptive test names with `@test "description"`
2. Include setup/teardown if needed
3. Mock external dependencies
4. Test both success and failure paths
5. Validate outputs and side effects