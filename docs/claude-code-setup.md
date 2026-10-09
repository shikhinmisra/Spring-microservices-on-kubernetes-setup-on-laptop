# Working on this repo with Claude Code

| Piece | Where | What it does |
|---|---|---|
| Project memory | `CLAUDE.md` | Facts, key commands and always-on rules (backend-only default, x64 images, tests, approvals). Loaded every session. |
| Skills | `.claude/skills/*/SKILL.md` | Step-by-step procedures, loaded only when needed: `/new-service`, `/add-feature`, `/release-version` (you start it; Claude won't on its own), `/deploy-local`, `/troubleshoot-cluster`. |
| Subagents | `.claude/agents/*.md` | `code-reviewer` (Java review), `test-engineer` (writes/runs Testcontainers tests), `k8s-manifest-reviewer` (kustomize/Argo CD review). Read-only except test-engineer, which only touches `src/test`. |
| Hooks | `.claude/settings.json` + `.claude/hooks/*.sh` | Run automatically (see below). |
| MCP servers | `.mcp.json` | `kubernetes` (read-only cluster inspection), `github` (issues, PRs, repo). |

## Hooks
| When | Script | Effect |
|---|---|---|
| Session start | `session-context.sh` | Adds a snapshot: git branch/dirty files, cluster reachable?, pods not running, Docker VM free memory, Harbor up? |
| Before every shell command | `guard-bash.sh` | **Blocks**: arm64 course images, skipping tests in `mvn`, `kubectl apply -f <folder>` / `-R`. **Asks you**: `kubectl delete`, `helm uninstall`, applying `extras`/`overlays/full`, force-push, `rm -r`, `wsl --shutdown`. |
| After editing a `.java` file | `format-java.sh` | Formats it with Spotless (palantir-java-format, configured in root `pom.xml`). Skips silently if Maven isn't available. |
| After editing k8s/argocd YAML | `check-k8s.sh` | YAML syntax, image policy (no arm64 images, no `latest` tags), renders all kustomizations. Problems are sent back to Claude to fix. |

Hooks are bash scripts; on Windows Claude Code runs them with Git Bash. `jq`/`python` are optional.

## One-time setup on the laptop
1. Node.js (for `npx`): `winget install OpenJS.NodeJS.LTS` — needed by the kubernetes MCP server.
2. GitHub MCP: create a fine-grained token (this repo only; Contents, Issues, Pull requests: read/write) and set it as a user
   environment variable `GITHUB_PAT` (`setx GITHUB_PAT <token>`, then open a new terminal). Never commit it.
3. Start `claude` in the repo root and approve the two project MCP servers when asked (`/mcp` shows their status).
4. Optional: Maven on PATH (`winget install Apache.Maven`) so the format hook and `mvn verify` run outside Docker.
   Testcontainers needs Docker Desktop running.

Personal overrides go in `.claude/settings.local.json` / `CLAUDE.local.md` (git-ignored).

## Changing the setup
- New repeatable procedure -> new folder in `.claude/skills/`. New always-true rule -> one line in `CLAUDE.md` (keep it short).
- After editing a hook, test it: `echo '{"tool_input":{"command":"kubectl delete pod x"}}' | bash .claude/hooks/guard-bash.sh`.
