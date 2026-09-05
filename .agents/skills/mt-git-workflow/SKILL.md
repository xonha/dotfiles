---
name: mt-git-workflow
description: Git branching, commit message conventions, and pull request process — branch naming, structured commits, gh CLI PR creation, and post-implementation Jira updates
---

# Git Workflow & Pull Requests

## Branch Naming Convention

All new development tasks must create a new Git branch originating from the `develop` branch.

### Pattern

```
<prefix>/<jira-card-id>-short-description
```

### Allowed Prefixes

- `feat` — for new features
- `fix` — for bug fixes
- `chore` — for maintenance tasks
- `refactor` — for non-functional code restructuring
- `test` — for tasks focused solely on improving or adding tests
- `docs` — for documentation-only changes

### Examples

For Jira card **GA-124**:

```bash
git checkout -b feat/GA-124-add-user-sync-endpoint
git checkout -b fix/GA-124-handle-null-response
git checkout -b chore/GA-124-update-ci-workflow
```

### Rules

1. **Always branch from `develop`**
2. Never commit directly to `develop` or `main`
3. The Jira card ID **must** be included in the branch name
4. The branch prefix must reflect the nature of the changes
5. The short description should be concise and kebab-cased

---

## Commit Messages

Use structured commit messages that clearly reference the card and describe the work:

```
<prefix>(GA-124): Brief description of change

Optional detailed explanation of the implementation,
rationale, and any important notes.
```

Example:

```
feat(GA-124): Add user sync endpoint

- Implements POST /users/sync endpoint
- Integrates with external user service
- Includes retry logic for failures
```

---

## Pull Requests

### Creating a Pull Request

Use the `gh` CLI to create a pull request:

```bash
gh pr create --base develop --title "Brief description"
```

The `gh` CLI will automatically open your default editor with the pull request template from `.github/pull_request_template.md`. Fill in all sections of the template completely.

**Important**: All PR descriptions must be written in Brazilian Portuguese.

### PR Template

**Always follow the pull request template** located at `.github/pull_request_template.md`. The template includes required sections:

- **What does this PR do?** — Clear summary of changes
- **Related to** — Link to Jira card (e.g., `GA-124`)
- **Testing** — Description of test coverage and how to verify
- **Checklist** — Pre-merge verification steps

Do not skip or remove any sections from the template.

### Final Steps After Implementation

Once implementation is complete and all tests pass:

1. Commit your code with structured commit messages (see above)
2. Open a Pull Request using the template
3. Update Jira with (in Brazilian Portuguese):
   - Summary of work done
   - Summary of relevant tests
4. Move the card from **DEV → TO DO CR**

```bash
jira issue move <JIRA-ID> --status "TO DO CR"
```
