# Google Drive / Google Docs I/O for legal skills

This document defines how legal skills (`review-contract`, `triage-nda`, etc.) read source documents from Google Drive and publish their output as new Google Docs.

It assumes the user has the Claude.ai Google Drive connector active (tools prefixed `mcp__claude_ai_Google_Drive__`).

## Identifying the source

A skill is operating against a Google Drive source when the user input is one of:

- A Google Docs URL: `https://docs.google.com/document/d/<FILE_ID>/...`
- A Google Drive file URL: `https://drive.google.com/file/d/<FILE_ID>/...`
- A bare file name (resolve via search) — e.g. `Acme x Lumen NDA - Draft v1`

If the input is a name, call `mcp__claude_ai_Google_Drive__search_files` with `query=<name>` and pick the best match. If multiple matches, ask the user to disambiguate before reading.

## Reading content (by source type)

| Source type | Tool | Notes |
|---|---|---|
| Native Google Doc | `mcp__claude_ai_Google_Drive__read_file_content` | Returns plain text. Heading structure is preserved as text. |
| `.docx` | `mcp__claude_ai_Google_Drive__read_file_content` | Drive extracts text. If extraction is empty, fall back to `download_file_content` and parse the binary. |
| Text-layer PDF | `mcp__claude_ai_Google_Drive__read_file_content` | Works for PDFs with an embedded text layer. |
| Scanned PDF (no OCR) | — | Not supported. Stop and ask the user to OCR first or paste the text manually. |

If reading returns nothing or fails, surface the error and stop — do not silently fall back to producing a generic review.

## Producing output as a sibling Google Doc

After the skill produces its markdown report:

1. Call `mcp__claude_ai_Google_Drive__get_file_metadata` on the source file ID to capture:
   - `name` (source file name, without trailing extension)
   - `parents[0]` (folder ID where the source lives)
2. Build the output Doc name using the skill's template (see "Naming conventions" below). Use today's date in `YYYY-MM-DD` format.
3. Call `mcp__claude_ai_Google_Drive__create_file` with:
   - `name` = output Doc name
   - `mime_type` = `application/vnd.google-apps.document`
   - `parents` = `[<source folder ID>]`
   - `content` = the markdown report from the skill
4. Return both:
   - The full markdown report inline in chat (so the conversation has the full record)
   - The new Doc's URL ("Saved to: https://docs.google.com/document/d/<NEW_ID>")

## Naming conventions

Each skill specifies its own template:

| Skill | Output Doc name template |
|---|---|
| `review-contract` | `<source name> — Legal Review <YYYY-MM-DD>` |
| `triage-nda` | `<source name> — NDA Triage <YYYY-MM-DD>` |

Strip any extension (`.docx`, `.pdf`) from `<source name>` when building the output name.

## Limitations

- **No in-place edits.** The current Drive MCP exposes no update/append/comment/suggestion tools. Reviews always go in a new Doc; the source is never modified.
- **Markdown rendering.** When `create_file` writes markdown into a Google Doc, headings and bold should render as Doc structure. If they appear as raw `#` and `**` characters, the workaround is documented under "Markdown rendering caveat" below.
- **Scanned PDFs** must be OCRed before invoking the skill.

## Markdown rendering caveat

If `create_file` deposits markdown as literal text rather than structured Doc content, two options:

1. Save the file as `mime_type=text/markdown` (kept as a text file in Drive — not ideal, since it won't open in Docs).
2. Build a follow-up step that converts the markdown to Docs API requests (`insertText` + `updateTextStyle` for headings/bold). This is deferred until smoke-testing confirms it's needed.

## Falling back when no Drive source is given

If the user pastes contract text or uploads a file directly (not via Drive), the skill behaves as it does upstream — produce the markdown report inline in chat. No Doc is created. The Google Drive output flow only applies when the source is in Drive.
