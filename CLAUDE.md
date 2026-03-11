# Installing this skill

When asked to install this skill from its GitHub URL, **always clone the repository first** using `git clone`. Never fetch individual files via URL.

```bash
git clone https://github.com/mvn-neumann/setup-playwright.git /tmp/setup-playwright
cd /tmp/setup-playwright
./install.sh
rm -rf /tmp/setup-playwright
```

This installs the skill to `~/.claude/skills/setup-playwright/SKILL.md`, making it available in all projects via `/setup-playwright`.
