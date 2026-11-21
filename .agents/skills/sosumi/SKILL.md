---
name: sosumi
description: Look up Apple API signatures, availability and behavior, Human Interface Guidelines, WWDC transcripts, and external Swift-DocC pages as Markdown via Sosumi.
---

# Look up Apple documentation

For a known developer.apple.com URL, keep the path and replace the host with sosumi.ai. When the path is unknown, use `searchAppleDocumentation(query:)` first and fetch the most specific match. Cite the Sosumi page so the reader can verify the answer.

| Source | MCP tool | Path or URL |
|---|---|---|
| Apple API reference | `fetchAppleDocumentation(path:)` | `/documentation/{framework}/{symbol}` |
| Human Interface Guidelines | `fetchAppleDocumentation(path:)` | `/design/human-interface-guidelines/{topic}` |
| Apple video transcript | `fetchAppleVideoTranscript(path:)` | `/videos/play/{collection}/{id}` |
| External Swift-DocC | `fetchExternalDocumentation(url:)` | Full HTTPS URL of the DocC page |

If MCP is unavailable, use the same paths at `https://sosumi.ai`. For external DocC, append the full HTTPS URL to `https://sosumi.ai/external/`. If using the CLI, check `sosumi --version` or `sosumi <command> --help`.

For a missing or sparse page, search again using the symbol name and its framework. For a blocked external host, try the canonical DocC URL. When conditional protocol conformance affects an implementation, verify the declaration in the installed SDK's `.swiftinterface` file. Apple's documentation data can omit or misstate the constraints.
