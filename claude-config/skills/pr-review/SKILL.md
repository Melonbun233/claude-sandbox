---
name: pr-review
description: Review a pull request for code quality, security, and correctness
disable-model-invocation: true
allowed-tools: Bash(gh *), Read, Grep, Glob
---

# PR Review Skill

Review a pull request following this process:

## 1. Gather Context
- Run `gh pr view <number> --json title,body,baseRefName,headRefName,files` to understand the PR
- Run `gh pr diff <number>` to get the full diff
- If files are large, read individual changed files with the Read tool

## 2. Analyze Changes
For each changed file, evaluate:
- **Correctness**: Logic errors, edge cases, null/undefined handling
- **Security**: Injection risks, auth issues, secrets exposure, OWASP top 10
- **Performance**: N+1 queries, unnecessary allocations, missing indexes
- **Maintainability**: Naming, complexity, duplication, missing tests

## 3. Format Review
Structure your review as:

### Summary
One paragraph overview of what the PR does and your overall assessment.

### Issues Found
List any bugs, security issues, or correctness problems. Mark severity (Critical/High/Medium/Low).

### Suggestions
Improvements that aren't blocking but would make the code better.

### Overall Assessment
- **APPROVE**: No blocking issues, code is ready to merge
- **REQUEST_CHANGES**: Has issues that must be fixed before merge
- **COMMENT**: Feedback provided, no strong opinion on merge readiness
