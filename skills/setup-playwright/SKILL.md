---
name: setup-playwright
description: Install, configure, and verify Playwright for Claude MCP browser automation and automated testing. Built for ddev + SilverStripe projects, also works standalone. Use when the user says "setup playwright", "install playwright", "configure playwright", or "/setup-playwright".
---

# Setup Playwright

Install, configure, and verify Playwright for both **Claude MCP** (browser automation) and **automated testing**. Built for **ddev + SilverStripe** projects, also works for standalone/non-ddev setups.

## Usage

```
/setup-playwright
```

## Flow Overview

The skill has two phases. The user chooses which phases to run:

- **Phase 1: MCP Setup** (Steps 0-3) — Install Playwright globally on the host and configure MCP for Claude Code browser automation
- **Phase 2: ddev Container** (Step 4, optional) — Also install Playwright inside the ddev container for projects that need it
- **Phase 3: Test Framework** (Steps 5-7) — Set up the Playwright test runner with project-specific config

At the end of Phase 1, if `IS_DDEV` is true, ask the user:
- **"Also set up Playwright inside the ddev container"** — continue to Phase 2 (Step 4), then ask about Phase 3
- **"Skip ddev setup, just host"** — skip to Phase 3 prompt

At the end of Phase 1 (non-ddev) or Phase 2 (ddev), ask the user:
- **"Also set up the test framework"** — continue to Phase 3
- **"Just MCP, I'm done"** — stop here

## Instructions

Follow all steps in order. **Check before each step** whether it's already done — skip completed steps silently.

---

### Step 0: Detect Project Context

Before starting, gather project context for use throughout:

1. **Detect ddev project:**
   ```bash
   ls .ddev/config.yaml 2>/dev/null
   ```

2. **If ddev project, get the project name:**
   ```bash
   grep '^name:' .ddev/config.yaml | awk '{print $2}'
   ```
   Save this as `PROJECTNAME`. It's used for container names (`ddev-PROJECTNAME-web`) and URLs (`https://PROJECTNAME.ddev.site`).

3. **If NOT a ddev project**, derive `PROJECTNAME` from the directory name:
   ```bash
   basename "$(pwd)"
   ```

4. **Detect platform:**
   ```bash
   uname -s
   ```
   Save as `PLATFORM` — needed for sudo handling in Step 2.

Save `PROJECTNAME`, `IS_DDEV` (true/false), and `PLATFORM` — these are referenced throughout.

---

### Step 1: Prerequisites Check

Verify the host machine has the required tools:

```bash
node --version
npm --version
```

If Node.js is missing or < 18, stop and tell the user to install Node.js 18+ first.

**If `IS_DDEV` is true**, also verify:

```bash
docker info > /dev/null 2>&1 && echo "Docker OK" || echo "Docker not running"
ddev --version
```

---

### Step 2: Install Playwright Globally on Host

**Always install globally** — this is the primary Playwright installation. ddev containers often have outdated Node/npm versions, so the host install ensures a reliable, up-to-date Playwright. The ddev container setup (Step 4) is optional and supplementary.

Install the MCP package and Playwright globally:

```bash
npm install -g @playwright/mcp@latest
```

Install browser binaries with system dependencies.

On **Linux/WSL2**, system dependencies require root:

```bash
sudo npx playwright install-deps
npx playwright install
```

On **macOS**, no sudo needed:

```bash
npx playwright install --with-deps
```

Verify:

```bash
npx playwright --version
```

---

### Step 3: Configure MCP for Claude Code

**Important:** If `.mcp.json` already exists, read it first and **merge** the new entries into the existing `mcpServers` object. Do not overwrite other MCP servers (e.g. trello).

If `.mcp.json` does not exist, create it.

**Always use the host-based config** — Playwright runs from the global host install (Step 2). This is the default for all projects, including ddev projects, because ddev containers often have outdated Node/npm versions.

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser", "chromium",
        "--headless"
      ]
    },
    "playwright-firefox": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser", "firefox",
        "--headless"
      ]
    },
    "playwright-webkit": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser", "webkit",
        "--headless"
      ]
    }
  }
}
```

**Tell the user:** "Restart Claude Code to load the new MCP servers."

---

**If `IS_DDEV` is true**, ask the user:

Use `AskUserQuestion` with options:
- **"Also set up Playwright inside the ddev container"** — continue to Step 4
- **"Skip ddev setup, host-only is fine"** — skip to the Phase 3 prompt below

**If `IS_DDEV` is false**, skip Step 4 entirely.

---

### Step 4: ddev Container Setup (optional, for ddev projects)

This step installs Playwright **inside the ddev container** as a supplement to the global host install. This is useful when you need browsers to run inside the container (e.g. for tests that must access container-only services, or to match the production environment).

Skip this entire step if `IS_DDEV` is false or the user chose to skip it.

#### 4a: Create Dockerfile for Playwright

**Check first:** If `.ddev/web-build/Dockerfile.playwright` already exists, read it and skip this sub-step unless it's outdated (missing key packages or wrong Node version).

Create `.ddev/web-build/Dockerfile.playwright`:

```dockerfile
ARG BASE_IMAGE
FROM $BASE_IMAGE

# Install system dependencies for Chrome, Firefox, and WebKit
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Chrome dependencies
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libdbus-1-3 libatspi2.0-0 libx11-6 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libgbm1 libxcb1 libxkbcommon0 \
    libpango-1.0-0 libcairo2 libasound2 \
    # Firefox dependencies
    libgtk-3-0 libxtst6 \
    # WebKit dependencies
    libwoff1 libopus0 libwebp7 libwebpdemux2 libenchant-2-2 \
    libgudev-1.0-0 libsecret-1-0 libhyphen0 libmanette-0.2-0 \
    libgdk-pixbuf-2.0-0 libegl1 libnotify4 libxslt1.1 libevent-2.1-7 \
    libgles2 libgstreamer-gl1.0-0 libgstreamer-plugins-base1.0-0 \
    gstreamer1.0-libav libxshmfence1 libglu1 \
    # Certificate tools (certutil for Chromium NSS database)
    libnss3-tools ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set Playwright browsers location
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers

# Create browsers directory
RUN mkdir -p /opt/playwright-browsers && chown -R www-data:www-data /opt/playwright-browsers && chmod -R 775 /opt/playwright-browsers

# Install Node.js 22 via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh && bash /tmp/nodesource_setup.sh && rm /tmp/nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node --version && npm --version

# Install Playwright and download browsers
RUN npm install -g playwright@latest && \
    npx playwright install-deps && \
    npx playwright install && \
    npm cache clean --force && \
    chown -R www-data:www-data /opt/playwright-browsers && chmod -R 775 /opt/playwright-browsers

# Marker file for idempotency
RUN touch /opt/playwright-browsers/.installed

EXPOSE 9323
```

#### 4b: Create ddev Playwright Config

**Check first:** If `.ddev/config.playwright.yaml` already exists, read it and skip unless outdated.

Create `.ddev/config.playwright.yaml`:

```yaml
web_build:
  - web-build/Dockerfile.playwright

web_extra_exposed_ports:
  - name: playwright
    container_port: 9323
    http_port: 9323
    https_port: 9324

web_environment:
  - PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
  - PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

hooks:
  post-start:
    - exec: |
        if [ ! -f /opt/playwright-browsers/.installed ]; then
          echo "Playwright browsers not found. Installing..."
          npx playwright install chromium firefox webkit
          touch /opt/playwright-browsers/.installed
        fi
    - exec: |
        # Install mkcert CA into browser trust stores so Playwright browsers
        # trust ddev's self-signed HTTPS certificates natively.
        # ddev mounts the mkcert CA at /mnt/ddev-global-cache/mkcert/rootCA.pem
        MKCERT_CA="/mnt/ddev-global-cache/mkcert/rootCA.pem"
        MARKER="/opt/playwright-browsers/.certs-installed"
        if [ -f "$MKCERT_CA" ] && [ ! -f "$MARKER" ]; then
          echo "Installing mkcert CA into browser trust stores..."
          # System trust store (used by WebKit)
          cp "$MKCERT_CA" /usr/local/share/ca-certificates/mkcert-root.crt
          update-ca-certificates
          # Chromium NSS database
          mkdir -p $HOME/.pki/nssdb
          certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n mkcert -i "$MKCERT_CA" 2>/dev/null || true
          touch "$MARKER"
          echo "mkcert CA installed for WebKit and Chromium."
        fi
```

#### 4c: Rebuild ddev

```bash
ddev restart
```

#### 4d: Verify inside container

```bash
ddev exec npx playwright --version
ddev exec ls /opt/playwright-browsers/.installed
```

#### 4e: HTTPS Certificates (automatic)

ddev uses mkcert for local HTTPS, but Playwright browsers running inside the container have their own certificate stores and don't trust the mkcert CA by default. This is handled automatically by the post-start hook above, which:

1. **WebKit** — Copies `rootCA.pem` into `/usr/local/share/ca-certificates/` and runs `update-ca-certificates` (system trust store)
2. **Chromium** — Uses `certutil` to add the CA to the NSS shared database at `~/.pki/nssdb/`
3. **Firefox** — Uses per-profile NSS databases that are hard to pre-configure; use `--ignore-https-errors` if running tests against HTTPS inside the container

The mkcert CA is auto-mounted by ddev at `/mnt/ddev-global-cache/mkcert/rootCA.pem`. The hook runs once and sets a marker file (`/opt/playwright-browsers/.certs-installed`) so it doesn't repeat.

**Note:** The MCP servers configured in Step 3 run on the **host**, not inside the container, so they use the host's certificate trust store. The container certificate setup only matters for tests or scripts that run Playwright inside the container (e.g. `ddev exec npx playwright test`).

**If certificate errors still occur** (e.g. after a ddev restart that cleared the marker), run:
```bash
ddev exec rm /opt/playwright-browsers/.certs-installed
ddev restart
```

---

**After Step 4 (or Step 3 for non-ddev), ask the user:**

Use `AskUserQuestion` with options:
- **"Also set up the test framework"** — continue to Step 5
- **"Just MCP, I'm done"** — skip to the Checklist section and stop

---

### Step 5: Test Framework Setup

Create the test directory structure and configuration files. Use `PROJECTNAME` from Step 0 wherever a project name is needed — never leave `PROJECTNAME` as a literal placeholder in any generated file.

#### 5a: Create directory structure

```bash
mkdir -p tests/playwright/tests
mkdir -p tests/frontend
```

#### 5b: Create `tests/playwright/package.json`

**Check first:** If `tests/playwright/package.json` already exists, skip.

```json
{
  "name": "playwright-tests",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "playwright test",
    "test:webkit": "playwright test --project=webkit",
    "test:chromium": "playwright test --project=chromium",
    "test:firefox": "playwright test --project=firefox",
    "test:ui": "playwright test --ui",
    "test:report": "playwright show-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.40.0",
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "dotenv": "^16.3.1"
  }
}
```

#### 5c: Create `tests/playwright/tsconfig.json`

**Check first:** If `tests/playwright/tsconfig.json` already exists, skip.

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "outDir": "./dist",
    "rootDir": "./tests",
    "types": ["node", "@playwright/test"]
  },
  "include": ["tests/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

#### 5d: Create `tests/frontend/tests.config.json`

**Check first:** If `tests/frontend/tests.config.json` already exists, skip.

This file is a shared config consumed by `playwright.config.ts` and can also be used by other frontend tools. Replace `PROJECTNAME` with the actual value from Step 0:

```json
{
  "baseUrl": "https://PROJECTNAME.ddev.site",
  "viewports": {
    "desktop": { "width": 1920, "height": 1080 },
    "tablet": { "width": 768, "height": 1024 },
    "mobile": { "width": 375, "height": 667 }
  },
  "timeout": 30000,
  "waitAfterLoad": 1000,
  "output": {
    "directory": "output",
    "baselineDirectory": "baseline",
    "diffDirectory": "diff"
  }
}
```

#### 5e: Create `tests/playwright/playwright.config.ts`

**Check first:** If `tests/playwright/playwright.config.ts` already exists, skip.

Replace `PROJECTNAME` with the actual value from Step 0:

```typescript
import { defineConfig, devices } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import dotenv from 'dotenv';

dotenv.config();

// Resolve base URL — checks SilverStripe/ddev env vars first, then shared config
let baseURL: string;
if (process.env.DDEV_PRIMARY_URL) {
  baseURL = process.env.DDEV_PRIMARY_URL;
} else if (process.env.SS_BASE_URL) {
  baseURL = process.env.SS_BASE_URL;
} else {
  try {
    const configPath = path.join(__dirname, '../frontend/tests.config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    baseURL = config.baseUrl;
  } catch {
    baseURL = 'https://PROJECTNAME.ddev.site';
  }
}

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'],
    ['html', { open: 'never', port: 9323 }]
  ],
  use: {
    baseURL,
    // Allow self-signed certs from ddev's mkcert local CA in dev/test only
    ignoreHTTPSErrors: !process.env.CI,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    // Desktop
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    // Tablet
    { name: 'webkit-tablet', use: { ...devices['iPad (gen 7)'] } },
    { name: 'chromium-tablet', use: { ...devices['iPad (gen 7)'], defaultBrowserType: 'chromium' } },
    // Mobile
    { name: 'webkit-mobile', use: { ...devices['iPhone 13'] } },
    { name: 'chromium-mobile', use: { ...devices['Pixel 5'] } },
    { name: 'firefox-mobile', use: { ...devices['Pixel 5'], defaultBrowserType: 'firefox' } },
  ],
});
```

**Note:** `__dirname` works because `tsconfig.json` uses `module: "CommonJS"`. If the project migrates to ESM, replace with `import.meta.dirname`.

#### 5f: Create `tests/playwright/tests/test-helpers.ts`

**Check first:** If `tests/playwright/tests/test-helpers.ts` already exists, skip.

These helpers are tailored for **SilverStripe projects** — they handle PHPDebugBar and common cookie consent banners. For non-SilverStripe projects the helpers still work: PHPDebugBar and cookie elements are simply not found and skipped gracefully.

```typescript
import { Page } from '@playwright/test';

interface PrepareOptions {
  waitForFonts?: boolean;
  closeCookieBanner?: boolean;
  closeDebugBar?: boolean;
  additionalWait?: number;
}

/**
 * Prepare a page for testing by waiting for full load and removing overlays.
 * ALWAYS call this after navigating to a page and before interacting with it.
 *
 * SilverStripe-specific: handles PHPDebugBar and cookie consent banners.
 * Non-SS projects: these are skipped gracefully if the elements don't exist.
 */
export async function preparePageForTest(page: Page, options: PrepareOptions = {}) {
  const {
    waitForFonts = true,
    closeCookieBanner = true,
    closeDebugBar = true,
    additionalWait = 0,
  } = options;

  // Wait for page to be fully loaded
  await page.evaluate(() => {
    if (document.readyState !== 'complete') {
      return new Promise<void>(resolve => window.addEventListener('load', resolve, { once: true }));
    }
  });

  // Wait for fonts
  if (waitForFonts) {
    await page.evaluate(() => (document as any).fonts.ready);
  }

  // Close cookie banner (common selectors — customize for your consent plugin)
  if (closeCookieBanner) {
    try {
      const cookieBtn = page.locator('#accept-cookies, .cookie-accept, [data-cookie-accept]').first();
      if (await cookieBtn.isVisible({ timeout: 1000 }).catch(() => false)) {
        await cookieBtn.click();
        await page.waitForTimeout(300);
      }
    } catch {
      // No cookie banner, continue
    }
  }

  // Close and remove PHPDebugBar (SilverStripe dev environments)
  if (closeDebugBar) {
    try {
      const closeBtn = page.locator('.phpdebugbar-close-btn');
      if (await closeBtn.isVisible({ timeout: 1000 }).catch(() => false)) {
        await closeBtn.click();
      }
    } catch {
      // No debug bar, continue
    }
    await page.evaluate(() => {
      document.querySelector('.phpdebugbar')?.remove();
      document.querySelector('.phpdebugbar-openhandler')?.remove();
    });
  }

  if (additionalWait > 0) {
    await page.waitForTimeout(additionalWait);
  }
}

/**
 * Navigate to a URL and prepare the page for testing in one call.
 */
export async function navigateAndPrepare(page: Page, url: string, options: PrepareOptions = {}) {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(1000);
  await preparePageForTest(page, options);
}
```

#### 5g: Create `tests/playwright/tests/example.spec.ts`

**Check first:** If `tests/playwright/tests/example.spec.ts` already exists, skip.

This smoke test verifies the setup works. Replace `PROJECTNAME` with the actual value from Step 0:

```typescript
import { test, expect } from '@playwright/test';
import { navigateAndPrepare } from './test-helpers';

test('homepage loads successfully', async ({ page }) => {
  await navigateAndPrepare(page, '/');
  await expect(page).toHaveTitle(/.+/);
});
```

#### 5h: Add `.gitignore` entries

Check the project's `.gitignore` and append these lines if not already present:

```
# Playwright test output
tests/playwright/test-results/
tests/playwright/playwright-report/
tests/playwright/node_modules/
tests/frontend/output/
tests/frontend/diff/
```

#### 5i: Install dependencies

For ddev projects:
```bash
ddev exec bash -c "cd tests/playwright && npm install"
```

For non-ddev projects:
```bash
cd tests/playwright && npm install
```

---

### Step 6: Verification

Run all verification steps to confirm everything works.

#### 6a: Playwright version

```bash
npx playwright --version
```

#### 6b: Test framework

For ddev:
```bash
ddev exec bash -c "cd tests/playwright && npx playwright test --list"
```

For non-ddev:
```bash
cd tests/playwright && npx playwright test --list
```

#### 6c: ddev container (if `IS_DDEV` is true)

```bash
ddev exec npx playwright --version
ddev exec ls /opt/playwright-browsers/.installed
```

#### 6d: MCP reminder

Tell the user: "Restart Claude Code to load the Playwright MCP servers. After restarting, test with `browser_navigate` on any URL."

---

## Troubleshooting

### Browser install fails on Linux/WSL2

System dependencies require root:

```bash
sudo npx playwright install-deps
npx playwright install
```

### MCP not available after setup

1. Verify `.mcp.json` exists in project root
2. Restart Claude Code (`/exit` and relaunch)
3. Check for conflicting MCP configs in `~/.claude.json`

### ddev container missing Playwright

```bash
ddev restart

# Or force reinstall
ddev exec bash -c "PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers npx playwright install"
```

### Wrong Node.js version in ddev container

The Dockerfile installs Node.js 22 via NodeSource. The `PATH` override in `.mcp.json` ensures it's used over nvm's version:

```
"-e", "PATH=/usr/bin:/usr/local/bin:/bin"
```

### npm permission errors (global install)

```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
# Add to ~/.bashrc or ~/.zshrc:
# export PATH=~/.npm-global/bin:$PATH
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `npx playwright --version` | Check Playwright version |
| `npx playwright install` | Install/update browsers |
| `npx playwright install --with-deps` | Install browsers + system deps |
| `npx playwright test` | Run all tests |
| `npx playwright test --project=webkit` | Run webkit tests only |
| `npx playwright test --ui` | Open interactive UI |
| `npx playwright show-report` | Open HTML test report |
| `npx playwright codegen URL` | Record tests interactively |
| `ddev exec npx playwright test` | Run tests inside ddev |

## Checklist

After running this skill, verify:

- [ ] `npx playwright --version` works on host
- [ ] `.mcp.json` exists with Playwright MCP entries (and preserves other entries)
- [ ] Claude Code restarted and MCP tools available
- [ ] (ddev) Container has Playwright installed
- [ ] (ddev) HTTPS certificates working
- [ ] (test framework) `tests/playwright/` directory structure created
- [ ] (test framework) `tests/playwright/package.json` dependencies installed
- [ ] (test framework) `tests/playwright/playwright.config.ts` has correct baseURL
- [ ] (test framework) `tests/playwright/tests/test-helpers.ts` exists
- [ ] (test framework) `tests/playwright/tests/example.spec.ts` exists
- [ ] (test framework) `.gitignore` entries added
