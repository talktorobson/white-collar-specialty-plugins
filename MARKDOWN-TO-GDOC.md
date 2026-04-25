# Markdown → Google Docs (shared workflow)

Pipeline used by any plugin in this fork that produces a structured markdown report and wants to publish it to Google Drive as a **native Google Doc** with real headings, bold, tables, and code blocks.

## When to use

- A skill emits a structured markdown report (legal review, NDA triage, finance reconciliation, marketing brief, etc.).
- The user works in Google Drive and wants the output as a Google Doc, not a `.md` file or escaped plaintext.
- The destination is a new Doc — this pipeline does **not** edit existing Docs in place.

## Dependencies

- **`pandoc`** (system) — install once: `brew install pandoc`. Verify: `pandoc --version`.
- **Anthropic's `document-skills` plugin** — installed at user scope from the `anthropic-agent-skills` marketplace. Provides the `docx` skill for richer Word-document workflows (find/replace, tracked changes, accept changes via `soffice`). For our plain markdown → .docx step we only use `pandoc`, but the skill is the right place to look when we need more.

If `pandoc` is missing, the skill should stop and tell the user to run `brew install pandoc` rather than silently fall back — the fallback path produces lower-fidelity output.

## Pipeline

1. **Skill emits markdown** to a temp file:
   ```
   /tmp/<skill-slug>-out-<YYYYMMDD-HHMMSS>.md
   ```

2. **Convert to .docx via pandoc**:
   ```
   pandoc -f markdown -t docx \
     -o /tmp/<skill-slug>-out-<ts>.docx \
     /tmp/<skill-slug>-out-<ts>.md
   ```
   Pandoc maps GitHub-flavored markdown to Word styles: `# / ## / ###` → Heading 1/2/3, `**` → bold, tables → real Word tables, code fences → preformatted blocks.

3. **Read the .docx as base64**:
   ```
   base64 -i /tmp/<skill-slug>-out-<ts>.docx | tr -d '\n'
   ```

4. **Upload to Drive** via `mcp__claude_ai_Google_Drive__create_file`:
   - `title` = output Doc name per the calling skill's naming convention
   - `mimeType` = `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
   - `parentId` = source's parent folder ID (from `get_file_metadata` on the source)
   - `content` = base64 string from step 3
   - Leave `disableConversionToGoogleType` at default (false) → Drive auto-converts the `.docx` into a native Google Doc with real structure.

5. **Return the new Doc's URL** to the user, plus the same markdown report inline in chat (so the conversation has the full record without needing to open Drive).

## Naming conventions

Each skill defines its own output Doc name. Examples:
- `<source name> — Legal Review <YYYY-MM-DD>` (legal/review-contract)
- `<source name> — NDA Triage <YYYY-MM-DD>` (legal/triage-nda)
- `<source name> — <skill-specific suffix> <YYYY-MM-DD>` (others)

Strip any extension (`.docx`, `.pdf`) from `<source name>` when building the output name.

## Cleanup

Delete the temp `.md` and `.docx` files after the upload returns successfully:
```
rm -f /tmp/<skill-slug>-out-<ts>.md /tmp/<skill-slug>-out-<ts>.docx
```

If the upload fails, leave the temp files in place so the user can recover or retry.

## Limitations

- **No in-place edits.** This pipeline always creates a new Doc. The Drive MCP exposes no update/comment/suggestion tools.
- **Images / embedded media** in the source markdown won't carry over unless they're addressable by URL — pandoc dereferences URLs but local image paths break.
- **Custom Doc styles** (your org's brand styles, fonts) aren't applied. Output uses pandoc's default Word styling, which Drive then converts. Customize by passing `--reference-doc=<template.docx>` to pandoc if needed.

## Fallback (when pandoc is unavailable)

If `pandoc` is genuinely unavailable on the host, the skill can fall back to:

1. Convert markdown to HTML inline (small Python or shell — headings + bold + lists work well; tables and code blocks render approximately).
2. Upload as `mimeType=text/html`. Drive converts HTML → Google Doc with most structure preserved.

This path is documented for completeness but should only be used when `brew install pandoc` is genuinely impossible. Headings render correctly; complex elements (nested tables, code fences with language hints) may render imperfectly.

## When richer Word-document handling is needed

For workflows beyond simple markdown → .docx — find/replace inside a Word file, accepting tracked changes, manipulating comments, working with .doc legacy files — invoke the user-level `docx` skill (from `document-skills@anthropic-agent-skills`). The skill provides scripts in its `scripts/` directory and patterns for unpacking/editing/repacking the underlying XML.

## Plugins currently using this pipeline

- `legal/skills/review-contract` (via `legal/GOOGLE-DOCS-WORKFLOW.md`)
- `legal/skills/triage-nda` (via `legal/GOOGLE-DOCS-WORKFLOW.md`)

When extending to other plugins (finance, marketing, productivity, etc.), have the calling skill reference this file directly or via a per-plugin workflow doc that defers to this one.
