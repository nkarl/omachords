# Repository workflow

- Perform all future development and iteration on the `work` branch.
- Keep `main` deployment-ready. Merge tested changes from `work` into `main` only when they are ready to publish.
- Do not commit experimental layouts, design notes, generated binaries, build output, or local runtime state to `main`.
- Before promoting changes to `main`, run the QML, JavaScript model, Rust engine, and Omarchy manifest validation commands documented in `README.md`.
- Keep Markdown prose paragraphs and list items on single physical lines; do not hard-wrap them.
