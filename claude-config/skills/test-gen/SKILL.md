---
name: test-gen
description: Generate unit tests for code
allowed-tools: Bash, Read, Write, Grep, Glob
---

# Test Generation Skill

Generate comprehensive unit tests for the specified code.

## Process

1. **Identify the target**: Read the file or module to test
2. **Detect language and framework**: Determine the language and existing test framework
   - Go: `go test`, testify
   - Python: pytest, unittest
   - JavaScript/TypeScript: jest, vitest, mocha
   - Java: JUnit, Mockito
3. **Analyze existing tests**: Check for existing test files and patterns
4. **Generate tests** covering:
   - Happy path for each public function/method
   - Edge cases (empty input, nil/null, boundary values)
   - Error paths and error handling
   - Integration points (mocked dependencies)
5. **Follow project conventions**: Match existing test file naming, structure, and patterns
6. **Verify**: Run the tests to ensure they compile and pass
