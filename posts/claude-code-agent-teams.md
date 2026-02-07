---
title: "Complete Guide to Claude Code Agent Teams: Coordinating Multiple AI Agents"
subtitle: "Learn how to orchestrate multiple Claude Code instances for parallel code reviews, debugging, and collaborative development"
tags: claudecode, ai, developer-tools, productivity, llm
cover_image: null
canonical_url: null
published: false
---

## Introduction

Complex software development tasks often benefit from multiple perspectives working in parallel. Claude Code's new experimental **Agent Teams** feature enables exactly this—coordinating multiple Claude Code instances that work together as a team.

In this comprehensive guide, we'll explore how Agent Teams work, when to use them, and walk through practical examples with best practices.

## What Are Agent Teams?

Agent Teams allow you to coordinate multiple Claude Code instances working together. The architecture consists of:

| Component | Role |
|-----------|------|
| **Team Lead** | The main session that creates the team, spawns teammates, and coordinates work |
| **Teammates** | Separate Claude Code instances that each work on assigned tasks |
| **Task List** | Shared list of work items that teammates claim and complete |
| **Mailbox** | Messaging system for communication between agents |

Unlike subagents that only report back to the main agent, teammates can message each other directly, share findings, and challenge each other's conclusions.

## Agent Teams vs Subagents: When to Use Which

| Aspect | Subagents | Agent Teams |
|--------|-----------|-------------|
| Context | Own window; results return to caller | Own window; fully independent |
| Communication | Report to main agent only | Direct teammate-to-teammate messaging |
| Coordination | Main agent manages all work | Shared task list with self-coordination |
| Best for | Focused tasks where only results matter | Complex work requiring discussion |
| Token cost | Lower (results summarized) | Higher (each is a separate instance) |

**Use subagents** when you need quick, focused workers that report back.
**Use Agent Teams** when teammates need to share findings and coordinate independently.

## Setting Up Agent Teams

### Step 1: Enable the Feature

Agent Teams are disabled by default. Add to your `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Step 2: Choose Display Mode

Two modes are available:

**In-process mode** (default): All teammates run inside your main terminal.
- Use Shift+Up/Down to select a teammate
- Press Ctrl+T to toggle the task list
- Works in any terminal

**Split panes mode**: Each teammate gets its own pane.
- Requires tmux or iTerm2
- See everyone's output at once

```json
{
  "teammateMode": "in-process"
}
```

## Practical Use Cases

### 1. Parallel Code Review

Single reviewers tend to focus on one type of issue. Split review domains for thorough coverage:

```
Create an agent team to review PR #142. Spawn three reviewers:
- One focused on security implications
- One checking performance impact
- One validating test coverage
Have them each review and report findings.
```

Each reviewer applies a different filter, and the lead synthesizes findings after they finish.

### 2. Debugging with Competing Hypotheses

When root causes are unclear, parallel investigation prevents anchoring bias:

```
Users report the app exits after one message instead of staying connected.
Spawn 5 agent teammates to investigate different hypotheses. Have them talk to
each other to try to disprove each other's theories, like a scientific
debate. Update the findings doc with whatever consensus emerges.
```

The theory that survives multiple investigators is more likely to be the actual root cause.

### 3. Cross-Layer Development

Changes spanning frontend, backend, and tests benefit from dedicated owners:

```
Create a team with 4 teammates to refactor these modules in parallel.
Use Sonnet for each teammate.
```

## Task Management

The shared task list coordinates work with three states:

- **Pending**: Not yet started
- **In Progress**: Currently being worked on
- **Completed**: Finished

### Task Dependencies

Tasks can depend on other tasks. A pending task with unresolved dependencies cannot be claimed until those dependencies complete.

### Task Claiming

- **Lead assigns**: Tell the lead which task to give to which teammate
- **Self-claim**: After finishing, teammates pick up the next unassigned, unblocked task

## Advanced Features

### Delegate Mode

Prevents the lead from implementing tasks itself. Press Shift+Tab to enable.

Useful when you want the lead to focus entirely on orchestration—breaking down work, assigning tasks, and synthesizing results.

### Plan Approval

Require teammates to plan before implementing:

```
Spawn an architect teammate to refactor the authentication module.
Require plan approval before they make any changes.
```

The lead reviews and approves plans before teammates begin implementation.

### Quality Gates with Hooks

Use hooks to enforce rules:

- **TeammateIdle**: Runs when a teammate is about to go idle
- **TaskCompleted**: Runs when a task is being marked complete

Exit with code 2 to send feedback and keep work going.

## Best Practices

### 1. Provide Sufficient Context

Teammates load project context automatically but don't inherit conversation history:

```
Spawn a security reviewer teammate with the prompt: "Review the authentication module
at src/auth/ for security vulnerabilities. Focus on token handling, session
management, and input validation. The app uses JWT tokens stored in
httpOnly cookies. Report any issues with severity ratings."
```

### 2. Size Tasks Appropriately

| Size | Problem |
|------|---------|
| Too small | Coordination overhead exceeds benefit |
| Too large | Long work without check-ins, wasted effort risk |
| Just right | Self-contained units with clear deliverables |

Aim for 5-6 tasks per teammate to keep everyone productive.

### 3. Avoid File Conflicts

Two teammates editing the same file leads to overwrites. Structure work so each teammate owns different files.

### 4. Monitor and Steer

Check in on progress regularly. Redirect approaches that aren't working. Don't let teams run unattended too long.

## Known Limitations

- **No session resumption** with in-process teammates
- **One team per session**
- **No nested teams** (teammates can't spawn their own teams)
- **Split panes** require tmux or iTerm2 (not supported in VS Code terminal)
- **Permissions** set at spawn time; all teammates start with lead's mode

## Conclusion

Claude Code Agent Teams represent a powerful new paradigm for AI-assisted development. By enabling multiple agents to work in parallel with direct communication, complex tasks like code reviews, debugging, and feature development can be tackled more efficiently.

Start with research and review tasks to understand the coordination model, then expand to more complex scenarios as you gain experience.

## References

- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
