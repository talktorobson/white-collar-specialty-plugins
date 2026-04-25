# Connectors

## How tool references work

Plugin files use `~~category` as a placeholder for whatever tool the user connects in that category. For example, `~~cloud storage` might mean Box, Egnyte, or any other storage provider with an MCP server.

Plugins are **tool-agnostic** — they describe workflows in terms of categories (cloud storage, chat, office suite, etc.) rather than specific products. The `.mcp.json` pre-configures specific MCP servers, but any MCP server in that category works.

## Connectors for this plugin (Robson's setup)

This plugin's `.mcp.json` is intentionally empty — all category placeholders resolve to user-level MCPs already connected via Claude.ai.

| Category | Placeholder | Resolved by | Notes |
|----------|-------------|-------------|-------|
| Calendar | `~~calendar` | Google Calendar (user-level Claude.ai connector) | |
| Chat | `~~chat` | Slack (user-level Claude.ai connector) | |
| Cloud storage | `~~cloud storage` | Google Drive (user-level Claude.ai connector) | Primary location for legal documents. Native Google Docs, `.docx`, and text-layer PDF supported per [`GOOGLE-DOCS-WORKFLOW.md`](GOOGLE-DOCS-WORKFLOW.md) |
| Email | `~~email` | Gmail (user-level Claude.ai connector) | |
| Office suite | `~~office suite` | Google Workspace (via Drive) | |
| Project tracker | `~~project tracker` | Atlassian / Jira (user-level Claude.ai connector) | ADEO context |
| E-signature | `~~e-signature` | **Clicksign** (no MCP — REST API only) | https://developers.clicksign.com/recipes — `signature-request` skill produces drafts; sending is manual |
| CLM | `~~CLM` | — | Not used |
| CRM | `~~CRM` | — | Not used |

## Why .mcp.json is empty

Plugin-level `.mcp.json` entries can duplicate or conflict with user-level connectors. Keeping it empty means:
- No double-binding of Gmail / Calendar / Drive / Slack / Atlassian
- Skills reference `~~category` placeholders, which Claude resolves at runtime to whatever MCP is available
- If this plugin is ever shared or used in a fresh Claude Code install, just re-add the relevant servers here

## Adding Clicksign as an MCP server (future)

Clicksign has no official MCP server. To automate e-signature workflows, build a small MCP wrapper around their REST API and add it here:

```json
{
  "mcpServers": {
    "clicksign": {
      "command": "node",
      "args": ["/path/to/clicksign-mcp/server.js"],
      "env": { "CLICKSIGN_TOKEN": "..." }
    }
  }
}
```
