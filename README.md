# setup-playwright

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that installs, configures, and verifies Playwright for both MCP browser automation and automated testing.

**Built for ddev + SilverStripe projects.** The skill auto-detects ddev containers, reads SilverStripe environment files (`_ss_environment.php`, `.env` with `SS_BASE_URL`), and includes helpers for PHPDebugBar and cookie banners common in SilverStripe sites. It also works for non-ddev/non-SilverStripe projects with a simpler host-only setup.

## What it does

- Installs Playwright and browser binaries on the host (or inside ddev containers)
- Configures `.mcp.json` for Claude Code browser automation (merges with existing entries)
- Sets up a ddev container with Playwright, Node.js 22, and all browser dependencies
- Scaffolds a Playwright test framework with TypeScript config and SilverStripe-aware helpers
- Auto-detects project name from `.ddev/config.yaml` or directory name
- Idempotent — safe to run multiple times, skips already-completed steps

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Node.js 18+
- For ddev projects: [ddev](https://ddev.readthedocs.io/) + Docker

## Installation

```bash
git clone https://github.com/mvn-neumann/setup-playwright.git ~/codebase/setup-playwright
cd ~/codebase/setup-playwright
./install.sh
```

This installs the skill to `~/.claude/skills/setup-playwright/SKILL.md`, making it available in all projects.

### Uninstall

```bash
rm -rf ~/.claude/skills/setup-playwright
```

## Usage

Inside any project directory:

```
/setup-playwright
```

Claude will:

1. Detect whether the project uses ddev (checks for `.ddev/config.yaml`)
2. Install Playwright and browsers **globally on the host** (always — ddev containers often have outdated Node/npm)
3. Configure MCP servers in `.mcp.json` using the host install (preserving existing entries like trello)
4. (Optional) Also set up Playwright inside the ddev container for in-container testing
5. Ask whether to also scaffold the test framework
6. (Optional) Create `tests/playwright/` with TypeScript config, test helpers, and a smoke test

## Three phases

| Phase | What it sets up | Steps | Required? |
|-------|----------------|-------|-----------|
| **1: MCP Setup** | Global Playwright install, `.mcp.json` | Steps 0-3 | Always |
| **2: ddev Container** | Dockerfile, config, cert trust for in-container use | Step 4 | Optional (ddev only) |
| **3: Test Framework** | `tests/playwright/` directory, config, helpers, example test | Steps 5-7 | Optional |

## Project types

### ddev + SilverStripe (primary target)

MCP servers run from the **global host install** via `npx` (not inside the container). This avoids issues with outdated Node/npm versions in ddev containers.

Optionally, Playwright can also be installed inside the ddev container for running tests via `ddev exec`. The skill creates:

- `.ddev/web-build/Dockerfile.playwright` — system deps, Node.js 22, browser binaries, `certutil` for certificate management
- `.ddev/config.playwright.yaml` — exposed ports, env vars, and a post-start hook that installs the mkcert CA into browser trust stores

The test framework reads `SS_BASE_URL` and `DDEV_PRIMARY_URL` for the base URL, and the test helpers handle SilverStripe-specific overlays (PHPDebugBar, cookie banners).

### HTTPS certificate handling

**Host MCP (default):** Browsers use the host's certificate trust store. If mkcert is installed on the host (`mkcert -install`), browsers already trust ddev's HTTPS certificates. No extra config needed.

**In-container testing (optional Phase 2):** Browsers inside the ddev container have their own trust stores. The skill's post-start hook handles this automatically:

| Browser | How the mkcert CA is trusted |
|---------|------------------------------|
| **WebKit** | Installed into the system trust store via `update-ca-certificates` |
| **Chromium** | Added to the NSS shared database via `certutil` |
| **Firefox** | Per-profile NSS databases are hard to pre-configure; use `--ignore-https-errors` for in-container tests |

The mkcert CA is auto-mounted by ddev at `/mnt/ddev-global-cache/mkcert/rootCA.pem`.

**Test framework:** `ignoreHTTPSErrors` is enabled only in non-CI environments (`!process.env.CI`) in `playwright.config.ts` to allow ddev's mkcert self-signed certificates in local development. In CI, HTTPS validation is enforced.

### Direct host (no Docker)

MCP servers run directly via `npx @playwright/mcp@latest`. No ddev files are created. The test helpers still work but the SilverStripe-specific parts (debug bar, cookie banner selectors) are skipped gracefully if not present.

## SilverStripe-specific features

The skill includes helpers tailored for SilverStripe projects:

- **Base URL resolution:** Checks `DDEV_PRIMARY_URL` > `SS_BASE_URL` > `tests.config.json` > fallback
- **PHPDebugBar removal:** Automatically closes and removes the debug bar from the DOM before tests
- **Cookie banner handling:** Clicks common accept buttons (`#accept-cookies`, `.cookie-accept`, `[data-cookie-accept]`)
- **Credential sources:** Reads from `.env` (with `SS_*` variables) and `_ss_environment.php`

These are all opt-in via the `preparePageForTest()` helper options. Non-SilverStripe projects can ignore or customize them.

## What gets installed

**Skill (global, via `install.sh`):**

```
~/.claude/
└── skills/
    └── setup-playwright/
        └── SKILL.md
```

**Project files (created at runtime by the skill):**

```
.mcp.json                             # MCP server config (merged into existing)
.ddev/                                # (ddev projects only)
├── web-build/
│   └── Dockerfile.playwright         # Browser deps + Node.js 22
└── config.playwright.yaml            # Playwright ddev config
tests/                                # (test framework only, Phase 2)
├── playwright/
│   ├── package.json                  # Dependencies: @playwright/test, typescript, dotenv
│   ├── tsconfig.json
│   ├── playwright.config.ts          # Multi-browser, multi-viewport config
│   └── tests/
│       ├── test-helpers.ts           # Page preparation utilities
│       └── example.spec.ts           # Smoke test to verify setup
└── frontend/
    └── tests.config.json             # Shared viewport/URL config
```

## Dependencies

The skill installs these npm packages:

| Package | Scope | Purpose |
|---------|-------|---------|
| `@playwright/mcp` | Global (host) | MCP server for Claude Code browser automation |
| `@playwright/test` | Project-local (`tests/playwright/`) | Test runner and assertions |
| `typescript` | Project-local | TypeScript compilation for test files |
| `dotenv` | Project-local | Load `.env` variables in test config |
| `@types/node` | Project-local | Node.js type definitions |

Browser binaries (Chromium, Firefox, WebKit) are installed via `npx playwright install`.

## License

[MIT](LICENSE)
