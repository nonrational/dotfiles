## Markdown Output

- When asked to produce markdown output (PR descriptions, docs, etc.), always reply with raw markdown source — `#`, `##`, `**`, backticks, etc. — so it can be copy-pasted directly into a markdown editor. Never render it as formatted output.
- When writing markdown documents with metadata headers (e.g., `**Prepared for:**`, `**Date:**`), add a backslash `\` at the end of each line to force line breaks. Without this, `pandoc` collapses consecutive bold lines into a single paragraph.
- When a markdown example itself contains a fenced code block (e.g. a ` ```markdown ` template that nests ` ```mermaid `, ` ```bash `, etc.), fence the OUTER example with tildes (`~~~`), not backticks. A `~~~` fence is only closed by `~~~`, so the inner ` ``` ` blocks nest cleanly — otherwise the first inner ` ``` ` prematurely closes the outer fence and the example renders broken.
