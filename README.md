# AI Agent setup

A repo for documenting and tracking AI agent setup.

## Claude Code

### Security

- [Docker sandboxes](https://docs.docker.com/ai/sandboxes/)
  - [Shim code](https://github.com/jrhender/sbx-claude-code-rc-shim) for  Claude Code Remote Control while in Docker Sandbox
  - [Sandboxing AI Coding Agents: nono vs Docker Sandboxes vs Microsandbox vs OpenShell](https://kudelskisecurity.com/research/sandboxing-coding-agents) (Kudelski Security, Nov 2026) — hands-on comparison of four agent sandboxes; all scored 4–4.5/5 and none is at v1.0 yet
- [Snyk Agent Scan](https://github.com/snyk/agent-scan) (to try) — scans installed agents, MCP servers and skills for prompt injection, tool poisoning, malware payloads, hardcoded secrets, etc. Supports Claude Code.
  - Cost: CLI is open source (Apache-2.0) and free to use, but needs a free Snyk account + `SNYK_TOKEN`; free tier has a daily scan limit. No paid subscription needed for personal use.
  - Note: sends component info (MCP configs, tool descriptions, skill content; secrets redacted) to Snyk's API, and may start stdio MCP servers to read tool descriptions, so run it inside a sandbox.

### Skills
- [Superpowers](https://github.com/obra/superpowers/)
- [Document Review](https://mcpmarket.com/tools/skills/document-review) (by EveryInc)
- [Ponytail](https://github.com/dietrichgebert/ponytail) (to try) — "lazy senior dev" skill/plugin that pushes the agent toward minimal code while still adding tests for risky logic (MIT)

### Status Line
- [ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine)
- [`sandbox-kits/claude-statusline`](sandbox-kits/claude-statusline/) — a Docker Sandboxes mixin kit that installs ClaudeCodeStatusLine into every `sbx run claude` sandbox

### Multiple account

https://github.com/realiti4/claude-swap 
