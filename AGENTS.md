# Repository instructions

## Code language

Write all code in English throughout this repository, regardless of the language used in the chat. Use English for all identifiers, including domain entities, models, types, properties, functions, parameters, variables, modules, files, and tests. Write code comments and documentation comments in English as well.

Use the intended locale for user-facing text and preserve user-entered content in its original language.

## Engineering practices

1. Keep working conventions here, product behavior in OpenSpec, and the reason for a non-obvious implementation choice beside the code it explains.
2. Before changing an API, inspect its callers and tests across TrainingKit, the app, and its extensions. Keep shared behavior in the module that owns it.
3. Test observable behavior through the entry point callers use. For a bug fix, reproduce the failure first when practical. Use an injected clock for timing and reopen a disk store when testing recovery.
4. Treat stored schemas and encoded payloads as compatibility contracts. When changing either, test with a frozen fixture written by the previous implementation. Preserve the original fixture when adding a newer one.
5. Keep each change scoped to its task. Run `swift test --package-path TrainingKit` with Xcode selected for package changes. Report the behavior verified and the environment used (macOS, simulator, or physical iPhone).

When creating a commit or drafting its message, use the [Git commit skill](.agents/skills/git-commit/SKILL.md).

Format edited Swift files with `xcrun swift-format format --in-place <files>`. Run the CI check from the repository root with `git ls-files -z -- '*.swift' | xargs -0 xcrun swift-format lint --strict`.

## Response style

Keep replies succinct, direct, and easy to scan. Flag deeper context with `[▶ Expand: Topic Name]` or “More details available upon request”. Expand only when asked.

## Apple documentation

Use the [Sosumi skill](.agents/skills/sosumi/SKILL.md) for Apple APIs, Human Interface Guidelines, WWDC transcripts, and external Swift-DocC documentation.
