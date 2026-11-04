# AGENTS.md

Reusable working agreement for coding agents and contributors.
Project-specific behavior belongs in /doc, not here.

## 0. Runtime guardrails (prominent)

- If the user asks to proceed autonomously, continue end-to-end but stop immediately and report when anything unusual appears.
- Avoid refactoring or redesign unless explicitly requested for the active task.
- Avoid extreme looping, repeated retries, or token/tool overuse; pause and report instead.
- Prefer safe incremental execution with checkpoints for long-running jobs.

## 1. Start-of-session checklist

Before proposing or making changes:

1. Read this file.
2. Read, in order when present:
   - /doc/requirements.md
   - /doc/design.md (or /doc/design-proposal.md)
   - active tickets (GitHub Issues by default, /doc/tickets/ as fallback)
   - docs referenced by the above
3. If docs are missing or ambiguous, ask focused questions.

## 2. Source of truth

- This file: ways of working.
- /doc/requirements.md: what to build.
- /doc/design.md (or /doc/design-proposal.md): solution design.
- Active GitHub Issues (or /doc/tickets/* fallback): approved implementation scope.

If docs conflict, project docs win for product behavior.
Do not invent requirements, API behavior, or UX rules.

## 3. Working rules

- Make small, coherent, reviewable changes.
- Preserve conventions unless change is justified.
- Prefer readable code over clever abstractions.
- Keep concerns separated (UI, domain, integration, data).
- Avoid premature optimization and speculative architecture.

## 4. Dependencies

Before adding a dependency:

1. State the problem it solves.
2. Explain why current tools are insufficient.
3. Note maintenance, security, license, and runtime or bundle impact.
4. Ask for approval before adding it.

## 5. Security and git safety

- Never commit or expose secrets.
- Keep secret files out of version control and ignored.
- Preserve unrelated user changes.
- Do not run destructive git commands without explicit permission.
- Do not commit, push, or deploy unless explicitly asked.

## 6. Delivery flow

1. Requirements are approved.
2. Design is approved.
3. Work from approved ticket scope.
4. Implement the smallest change that meets acceptance criteria.
5. Update docs when behavior or operations change.

## 7. Ticketing workflow

- Default tracker: GitHub Issues per repository.
- Keep ticket states simple: Todo, In Progress, Blocked, Done.
- AI should implement from approved issues.
- If work is requested without an issue, create/draft one first and confirm scope.
- Link code and docs back to issue IDs.
- Update issue progress notes after meaningful work sessions.

## 8. Verification and reporting

- Add or update tests for non-trivial logic.
- Run relevant checks available in the project.
- Report exactly what ran and what passed or failed.
- Never claim unrun checks passed.

## 9. Done criteria

A task is done when acceptance criteria are met, checks are reported, docs are updated as needed, no secrets were introduced, and unrelated changes are excluded.

## 10. Suggested doc set for new projects

- /doc/requirements.md
- /doc/design.md (or /doc/design-proposal.md)
- /doc/tickets/
- /doc/operations.md
- /doc/decisions/ (optional)
