---
name: mt-dev-workflow
description: 5-step development workflow for starting a task from a Jira card — reading the card, branching, analysis, clarification loop, and finalizing the plan
---

# Development Workflow

The development workflow follows a 5-step process before implementation begins.

## Step 1: Read the Jira Card

When a user provides a Jira card ID:

1. Retrieve the issue details using the `jira` CLI command
2. Read the title, description, acceptance criteria, and attachments
3. Extract scope, expected behavior, and points of ambiguity

```bash
jira issue view <JIRA-ID> --raw
```

---

## Step 2: Move the Card to "DEV"

Transition the Jira issue from **READY FOR DEV → DEV** before producing analysis.

Also create a feature branch from `develop` following the Git Workflow conventions.

```bash
jira issue move <JIRA-ID> --status "DEV"
```

---

## Step 3: Produce Analysis & Implementation Plan

Output two clear sections:

### A. Understanding / Interpretation

- Summary of what the card requires
- Identification of input/output behavior
- Clarification of missing details
- Impact on existing architecture
- External system or AWS service interactions
- Required data transformations, models, or endpoints

### B. Implementation Plan

A highly detailed engineering plan including:

- Architecture updates
- API endpoint definitions (if applicable)
- Changes to AWS resources (Lambda, SQS, DynamoDB, etc.)
- Data models / JSON schemas
- Execution flow diagrams (if needed, described textually)
- Test strategy
- Edge cases
- Error handling strategy
- Risks or dependencies

---

## Step 4: Clarification Loop With the User

A collaborative phase where:

- The user may correct assumptions
- The user may adjust or expand requirements
- The plan is refined iteratively

**This loop continues until the user explicitly confirms final approval.**

---

## Step 5: Finalize Plan & Update Jira Card

After approval:

- The card remains in **DEV**
- Proceed to implementation
