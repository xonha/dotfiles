---
name: plunz
description: Work on PLUNZ products, shared brand decisions, and plu.nz integrations from any working directory. Use for PLUNZ repositories or when a Bazzite service change affects PLUNZ domains, public copy, or shared product decisions; pair with the bazzite skill for host operations.
metadata:
  short-description: PLUNZ product and repository context
---

# PLUNZ

The shared PLUNZ source of truth is `/home/henrique/Projects/plunz` (the `plu-nz/.github` repository). This skill provides an entry point from any working directory; use absolute paths or set a command's working directory as needed. Do not assume the current directory is a PLUNZ checkout. If that path is unavailable, locate the `plu-nz/.github` checkout and read its current files before relying on remembered details.

## Start with the owning source

- For brand or cross-product work, read the shared checkout's `README.md`, `CONTEXT.md`, `AGENTS.md`, and relevant accepted files in `decisions/`. Treat current files as authoritative over this summary. Distinguish confirmed facts, proposals, and pending decisions.
- For product work, identify its repository using the shared `REPOS.md` and the checkout's Git remote. Read that repository's `README.md`, `AGENTS.md`, and narrower instructions; inspect Git status before edits. `repos/*` are independent Git repositories. Keep product implementation and commits there, and never add them to the shared repository.
- Run the shared checkout's `sync-repos.sh` only when current organization sources are needed. For codebase questions, use an existing `graphify-out/graph.json` where suitable. If extracting from the shared root, pass `--no-gitignore` to include ignored product checkouts.

## Shared decisions

- PLUNZ is a toolbox of small, independent apps. The GitHub organization is `plu-nz`; `plu.nz` is the main domain. Public product names and subdomains are decided individually. Follow `decisions/2026-11-03-repository-naming.md` for new repository names.
- Write repository documentation, code comments, issues, pull requests, commit messages, and default public copy in English. For user-facing apps, follow `decisions/2026-11-04-product-localization.md`: English, Portuguese, and Spanish; device language by default; English fallback; an accessible language selector; shared `plunz_locale` cookie on `plu.nz` with a local fallback. Keep translations with each product's source.
- For new work, follow `decisions/2026-11-03-architecture-and-stack.md`: SolidJS + TypeScript + Vite for web UI; Hono + TypeScript for suitable hosted APIs; Go where it fits no-cost hosting and low operations, especially for CLIs and non-UI programs. Do not use TanStack Start. Use pnpm for JavaScript and TypeScript projects.
- Design product apps mobile first and make web product apps installable on smartphones, per `decisions/2026-11-04-mobile-first-and-installable-apps.md`. The marketing hub is outside the product PWA requirement. Use `lib.storybook` for shared SolidJS tokens and components, adopting them in focused product changes.
- Prefer simple, modular, no-cost solutions with little self-hosting and few providers. Cloudflare is preferred where appropriate, not mandatory. Do not assume access to a user's Google Drive or Photos; validate permissions, limits, and intended experience before choosing an integration.
- Record cross-product decisions in the shared `decisions/` directory and product details in the owning repository. Follow the shared repository's index and `README.md` requirements when changing its directory structure. Each product repository needs its own complete `AGENTS.md`.

## Bazzite boundary

Use this skill when PLUNZ branding, `plu.nz` domains, public sites, or cross-product decisions intersect with the Bazzite host. For host state, containers, mounts, Tailscale, tunnels, and service deployments, also use `$bazzite` and its current Dotfiles runbooks. For versioned Dotfiles or deployment-file changes, also use `$dotfiles`. Keep host operations and service facts grounded in those sources; this PLUNZ skill does not authorize changes to live services or DNS. `web.bazzite` is a separate PLUNZ product repository for public information and privacy copy, not the host's operational source of truth.
