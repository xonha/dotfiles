---
name: tools-and-commands
description: CLI reference for jira, gh, pytest, and make commands used throughout the development workflow
---

# Tools & Commands Reference

This page documents the CLI tools and commands used throughout the development workflow.

## Jira CLI

Use the `jira` command for all Jira interactions. This integrates with the Jira workspace.

### Common Commands

**View an issue:**

```bash
jira issue view <JIRA-ID>
# Example: jira issue view GA-124
```

**Move issue to a different status:**

```bash
jira issue move <JIRA-ID> --status "<STATUS>"
# Example: jira issue move GA-124 --status "DEV"
# Example: jira issue move GA-124 --status "TO DO CR"
```

**Add a comment to an issue:**

```bash
jira issue comment add <JIRA-ID> "<COMMENT_TEXT>"
# Example: jira issue comment add GA-124 "Implementation complete, ready for review"
```

All Jira comments must be written in Brazilian Portuguese.

**List issues assigned to you:**

```bash
jira issue list --assignee @me
```

### Key Usage in Workflow

- **Step 1** — View the card: `jira issue view <JIRA-ID>`
- **Step 2** — Move to DEV: `jira issue move <JIRA-ID> --status "DEV"`
- **Final** — Move to TO DO CR: `jira issue move <JIRA-ID> --status "TO DO CR"`

---

## GitHub CLI

Use the `gh` command for GitHub operations (PRs, issues, etc.).

### Common Commands

**Create a pull request:**

```bash
gh pr create --base develop --title "<TITLE>"
```

The `gh` CLI will automatically open your editor with the PR template from `.github/pull_request_template.md`. Complete all sections of the template.

All PR descriptions must be written in Brazilian Portuguese.

**View pull request status:**

```bash
gh pr view
```

**List your pull requests:**

```bash
gh pr list --assignee @me
```

**Check PR CI status:**

```bash
gh pr checks
```

---

## Project Commands

### Make Targets

**Start infrastructure for tests:**

```bash
make run-spec-infra
```

**Run tests:**

```bash
pytest
pytest --cov=src
pytest -v
```

### Virtual Environment

**Activate the virtual environment:**

```bash
source .venv/bin/activate
```

**Deactivate the virtual environment:**

```bash
deactivate
```

---

## Workflow Command Shortcuts

Here's a typical command sequence for a development task:

```bash
# Prepare environment
source .venv/bin/activate
make run-spec-infra
pytest

# Create feature branch
git checkout -b feat/GA-124-add-user-sync-endpoint

# View the issue
jira issue view GA-124

# Move issue to DEV
jira issue move GA-124 --status "DEV"

# ... Work on implementation ...

# Run tests
pytest

# Commit and create PR
git add .
git commit -m "feat(GA-124): Add user sync endpoint"
gh pr create --base develop --title "feat: Add user sync endpoint" --body "Closes GA-124. See PR template."

# Move issue to TO DO CR
jira issue move GA-124 --status "TO DO CR"
```
