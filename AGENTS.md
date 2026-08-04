# AutoSpec Implementation Guidance

## Project Context

- `Vehicle_Data` is the FastAPI backend.
- `Vehicle_App` is the Flutter frontend.

## Working Agreement

- Never make architectural changes without asking.
- Prefer the smallest correct patch and preserve the existing code style.
- Before changing code, explain the plan in five bullets or fewer.
- If a change affects the API, identify the Flutter impact before implementation.
- If behavior or scope is unclear, stop and ask instead of guessing.
- Never rewrite large files unless explicitly requested.
- After coding, run relevant tests, summarize the changed files, and explain why each file changed.
- Keep one logical change per commit, and keep commits clean and descriptive.
- ChatGPT and the user own architecture, debugging direction, and final code review; Codex owns the approved implementation work.
