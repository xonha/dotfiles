---
name: lab
description: >
  Use Henrique's Bazzite Lab via ssh lab for software development across
  projects and client machines. Edit the remote checkout, run dependencies,
  builds, tests, and dev services remotely, and deliver browser previews
  through SSH forwarding.
---

# Lab development

Use the client machine for SSH, editing through remote tools, and viewing
previews in the browser. Run project commands, including dependency installs,
lint, tests, builds, dev servers, and supporting services, inside the Lab
container reached by `ssh lab`.

## Work in the remote checkout

- Find the project under `/workspace`, the persistent workspace in the Lab.
  Check the branch and worktree status and read the repository instructions
  there. Reuse the existing checkout. Clone into `/workspace` if the project
  is missing and its repository URL is known.
- Treat the Lab checkout as the source of truth for the task. Use a remote
  editor or transfer a targeted patch and apply it there over SSH. If an
  existing client checkout has uncommitted work needed for the task, inspect
  both checkouts and carry over the relevant changes without overwriting edits
  on either side.
- Use the project's normal commands from its remote directory. If a tool
  configured by mise is absent in a noninteractive SSH session, use
  `mise exec -- <command>` from the project directory.
- For command-only SSH sessions, add `-o ClearAllForwardings=yes` so the
  alias's default port forward leaves port 3000 available for previews.

## Deliver a browser preview

Start the dev server inside Lab, binding to its loopback interface when the
framework supports it. Use an agent-managed background session or a named
tmux session when the preview should stay available after the task. Stop
task-owned services when they are no longer needed and keep requested previews
running for review.

Forward each browser-facing port to client loopback. The standard `lab` alias
already forwards port 3000. For a server on 5173, an example is:

```bash
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:5173:127.0.0.1:5173 lab
```

The example also inherits the alias's port 3000 forward. If 3000 is already
occupied, reuse the existing tunnel if it reaches the intended server, or
make an explicit connection using the alias's resolved host, user, and port
(`ssh -G lab`) with only the required forwards. If a local preview port is
occupied, choose a free local port and forward it to the actual remote port.
Route browser-facing APIs and hot reload through the forwarded origin or
forward their ports separately when required.

Check the app inside Lab, then check the forwarded URL from the client.
Report the client URL, such as `http://127.0.0.1:5173`, and how to stop any
preview processes or tunnel left running. Use private, local forwarding by
default.

## If Lab is unavailable

Check the SSH alias and connection. Use the `bazzite` skill for host or
Lab-container administration. If remote development remains blocked, report
the blocker and get Henrique's approval before running project workloads on
the client machine.
