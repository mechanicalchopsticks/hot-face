---
name: git-commit
description: Use when creating a Git commit or drafting its message in this repository. Group changes by purpose and write a conventional subject followed by a concise rationale.
---

# Create a focused commit

Review `git status --short`, `git diff`, and `git diff --cached`. Identify one purpose that explains every hunk in the commit. Include the implementation, regression tests, and documentation that serve that purpose. Split independently useful changes into separate commits.

Stage the relevant paths, or individual hunks when a file mixes purposes. Preserve unrelated work, including the user's existing staging choices. If unrelated changes are already staged, use an isolated index or a path-limited commit of fully reviewed files. Inspect the exact patch to be committed before committing.

## Write the message

Use `type: summary` or `type(scope): summary` when a scope such as `sessions` clarifies the change. Write a brief, single-line subject in the imperative. Use English by default, consistent with this repository's history.

Choose the prefix by the primary purpose of the commit:

| Prefix | Purpose |
|---|---|
| `feat` | Add a capability |
| `fix` | Correct unintended behavior |
| `core` | Change shared project foundations, such as domain or persistence infrastructure |
| `docs` | Update documentation or written guidance |
| `refactor` | Restructure existing code while preserving behavior |
| `test` | Add or improve test coverage |
| `ci`, `build`, `chore` | Update automation, build configuration, or routine maintenance, respectively |

Leave a blank line after the subject. Always write a short paragraph explaining **why** the change is needed and what outcome it enables. Add a GitHub-compatible Markdown list after the paragraph only when it makes related details easier to scan.

```text
test(sessions): cover retries after a session closes

A retry can arrive after the session has ended. Replaying a stored V2
receipt checks that future changes still recognize the original set.
```
