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
3. Run the markdown → `.docx` → upload pipeline (detailed in "Markdown to Google Docs pipeline" below). Output target:
   - `title` = output Doc name from step 2
   - `parentId` = the folder ID from step 1
4. Return both:
   - The full markdown report inline in chat (so the conversation has the full record)
   - The new Doc's URL ("Saved to: https://docs.google.com/document/d/<NEW_ID>")

## Markdown to `.docx` pipeline (standard output format)

The standard output for legal skills is a `.docx` file in Drive, produced via `pandoc`. This gives full headings, bold, tables, and code blocks. Drive previews `.docx` inline with full formatting and offers one-click "Open with Google Docs" for native editing.

**Dependencies**: `pandoc` (system, install once with `brew install pandoc`). If missing, stop and tell the user to install it — do not fall back to `text/plain` upload, which produces escape-character output.

**Steps**:

1. Write the skill's markdown report to a temp file:
   ```
   /tmp/<skill-slug>-out-<YYYYMMDD-HHMMSS>.md
   ```
2. Convert to `.docx`:
   ```
   pandoc -f markdown -t docx \
     -o /tmp/<skill-slug>-out-<ts>.docx \
     /tmp/<skill-slug>-out-<ts>.md
   ```
2a. Strip pandoc's empty `comments.xml` and unused footnote-rels (or Word will show *"Word found unreadable content"* on open):
   ```
   <repo-root>/scripts/clean-pandoc-docx.sh /tmp/<skill-slug>-out-<ts>.docx
   ```
3. Read the `.docx` as base64:
   ```
   base64 -i /tmp/<skill-slug>-out-<ts>.docx | tr -d '\n'
   ```
4. Upload via `mcp__claude_ai_Google_Drive__create_file` with:
   - `title` = output Doc name (from step 2 of the parent flow)
   - `mimeType` = `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
   - `parentId` = source's parent folder ID
   - `content` = base64 from step 3
5. Delete the temp `.md` and `.docx` files after upload succeeds. Leave them in place if the upload fails (so the user can recover).

When returning the URL, briefly tell the user: *"Saved as `<name>.docx`. Drive renders it inline; click 'Open with Google Docs' for native editing."*

The same pipeline applies to all plugins in this fork — see the repo-root [`MARKDOWN-TO-GDOC.md`](https://github.com/talktorobson/white-collar-specialty-plugins/blob/customize/legal-robson/MARKDOWN-TO-GDOC.md) for cross-plugin documentation. A native gdoc output (`application/vnd.google-apps.document`) would require a custom MCP server wrapping the Google Docs API — deferred.

## Naming conventions

Each skill specifies its own template:

| Skill | Output Doc name template |
|---|---|
| `review-contract` | `<source name> — Legal Review <YYYY-MM-DD>` |
| `triage-nda` | `<source name> — NDA Triage <YYYY-MM-DD>` |

Strip any extension (`.docx`, `.pdf`) from `<source name>` when building the output name.

## Limitations

- **No in-place edits.** The current Drive MCP exposes no update/append/comment/suggestion tools. Reviews always go in a new Doc; the source is never modified.
- **Scanned PDFs** must be OCRed before invoking the skill.
- **`pandoc` required** for the markdown → Doc conversion. If missing, stop and tell the user to run `brew install pandoc` rather than fall back to the lower-fidelity `text/plain` upload (which produces escape-character output).

## Falling back when no Drive source is given

If the user pastes contract text or uploads a file directly (not via Drive), the skill behaves as it does upstream — produce the markdown report inline in chat. No Doc is created. The Google Drive output flow only applies when the source is in Drive.
