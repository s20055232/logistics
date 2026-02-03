---
name: commit-message
description: Analyzes staged git changes and generates a conventional commit message
allowed-tools: Bash
---

# Commit Message Generator

Generate a commit message for staged changes using Conventional Commits format.

## Execution Flow

1. Run `git diff --staged --stat` to check if there are staged changes
   - If no staged changes, inform user and stop

2. Run `git diff --staged` to analyze the actual changes

3. Generate a commit message following Conventional Commits:
   - Format: `type(scope): description`
   - Types:
     - `feat`: New feature
     - `fix`: Bug fix
     - `docs`: Documentation only
     - `style`: Formatting, no code change
     - `refactor`: Code restructure, no behavior change
     - `test`: Adding/updating tests
     - `chore`: Build, CI, dependencies
   - Scope: The module/component affected (optional but recommended)
   - Subject: Imperative mood, lowercase, no period, max 72 chars
   - Body: If changes are complex, add a blank line then explanation

4. Output the suggested commit message in a code block for easy copying

## Output Format

```
<type>(<scope>): <subject>

[optional body explaining the why, not the what]
```

## Example Output

```
feat(auth): add JWT token refresh mechanism

Tokens now auto-refresh 5 minutes before expiration to prevent
session interruptions during active use.
```
