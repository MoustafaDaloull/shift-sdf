# Changelog — Shift SDF

All framework changes are recorded here. The framework obeys its own rules: a standard is never edited silently; every change carries a version and a reason.

## 0.2.2 — 2026-10-28

Agent context economy, measured on a second project running this framework.

**Governance**
- `governance/execution-instructions.md` 0.2.1 — **new §8.6**. (a) An agent is assigned a **track**, not a task: a subagent is an independent conversation that loads its whole context at startup and shares nothing with its siblings, so the unit of assignment is a full module slice it lives with until closure, the size cap belongs to the **pull request** and not to the agent, shared files / integration / decisions / `HG-I-*` gates and anything finishing in under ~10 turns stay with the integration owner in the parent session, and a broad **read** agent is the exception — judged by the context it keeps out. The worktree limit N is unchanged. Measured: 174 subagents over seven days, median 0.84 MB, 55% under 1 MB, against parent sessions averaging 48.6 MB — more than half of the week's agents did less work than their own startup cost. (b) **Context handover before clearing**: a summary printed in the conversation is erased with it, so the order is three steps — request it, write it somewhere durable, then clear and point the next session at the file. Defines what it carries (the §17 closing-report lines plus pending approvals, branch heads and open PR numbers), where each kind belongs, when clearing pays off and when it does not, and that the agent prepares the file and names its path but never clears on its own.
- `governance/PROJECT-CONSTITUTION.md` 1.1 — §10(8) assignment by track, not by task; §13(7) context is not cleared before it is written; two new rows in the measured-lessons table.

**Lessons** — `L-053` (agent assigned to a track, not a task) and `L-054` (a handover summary printed in the conversation is erased with it).

**Checklists** — `slice-closure.md` 0.2.1 gains the handover-file item for a session about to be closed or cleared.

## 0.2.1 — 2026-10-12

- `README.md §9` is now the **end-to-end execution guide**: a stage map (0–11) with exit gates, the steps of every stage from the foundational discovery to UAT, handover and project closure, the three loops that run inside every stage (decision closing, change request, report-and-stop), the roles per stage, and a measured timeline example from the reference project. Stage §9.2 absorbs the former "how a new project starts" list.

## 0.2.0 — 2026-10-12

Updated from the reference project's experience between the first extraction (2026-10-01, CR-362) and 2026-10-12 (CR-428): the English-language programme, the SEO programme, the Phase 1B readiness review, the QA-report programme with its comprehensive re-check, the parallel-limit raise, the CI mirror, and the opening of a second project from the framework.

**Governance**
- `governance/PROJECT-CONSTITUTION.md` — the constitution: the rules that do not change from project to project (ten articles, roles and authority, source-of-truth ladder, lifecycle, method, gate principles, human decision gates, Git and parallelism, records and numbering, environment, the agent and its memory, measured lessons, start list, per-project adaptation table). Installed as `CONSTITUTION.md`; every `CLAUDE.md` rule traces to an article.
- `governance/execution-instructions.md` 0.2.0 — §8.4 worktree limit raised only by a recorded decision backed by a capacity measurement and proven by a deliberate breach; **new §8.5** multi-cycle programmes; §9.1 `GATE-I18N` row; §14 number reservation between concurrent sessions, date from the machine clock, post-merge steps; §16 warnings 9–12; §17 report lines for delegated decisions and the resume point, explicit continuation mandate, declared slips, subagent WIP preservation.

**Standards**
- New `standards/internationalization-standard.md` (`I18N-*`) and `standards/seo-public-visibility-standard.md` (`SEO-*`) — wave 3, applied by project scope and declared `N/A` out loud otherwise.
- `coding-standards.md` 0.2.0 — `CS-052` displayed text is not data, `CS-053` no technical token in a user message, `CS-054` translated validation attribute names.
- `automation-strategy.md` 0.2.0 — `AS-037` translation gate, `AS-062` Docker Hub mirror in CI.

**Templates**
- New `templates/discovery/discovery-brief-template.md` — the foundational discovery brief for a project that starts from raw documents (source inventory, conflict and gap registers, questions with options and a recommendation, specification-readiness verdict).
- New `templates/programmes/` — `phase-readiness-review.md`, `qa-report-programme.md` (including the QA-report and per-module acceptance-workbook column schemas and the three-lane comprehensive re-check), `i18n-programme.md`, with a README of shared programme rules.
- `templates/implementation/definition-of-done.md` — suspended test writing becomes measured debt accepted by decision at its size; money slices are named exceptions.

**Scripts**
- New `GATE-I18N` stage (`scripts/i18n/i18n-check.cjs` · `refresh-baseline.sh` · `literals.baseline.json`), configured in `shift.env` (`I18N_*`), `auto` mode declares N/A out loud for single-language projects.
- `agent-worktree.sh` — terminates an env file before appending (an unterminated last line glued `PORT_SLOT` onto it and every tree got slot 1); limit message names the config variable and the measurement rule.
- `scenario-check.sh` — scenario IDs wrapped in backticks in table rows are read (two whole packages had been read as undefined).
- `shift.env` — `MAX_EXTRA_WORKTREES` documented with the measurement rule.

**Profile `laravel-react`** 0.2.0 — CI pulls Docker Hub images through `mirror.gcr.io` in both the daemon and BuildKit (two runs had died before any gate on an anonymous-pull rate limit); `@formatjs/icu-messageformat-parser` dev dependency for the translation gate; README §4A (second language) and §4B; new `docs/local-setup-without-docker.md`.

**Lessons** — L-036..L-052: capacity-measured worktree limit, unterminated env file, backticked IDs, infrastructure failure before the first gate, split sentences, `Accept-Language`, text as data, duplicate fields, the primary page never waits, the literal snapshot as protection without tests, subagents widening permissions, number reservation, date from the clock, demo-only seeds, the comprehensive re-check, ceilings on every activation path, retired audit types.

**Checklists** — new `release-to-staging.md`; `project-start.md` gains §0 discovery, the constitution, language/visibility and worktree-limit decisions, agent memory; `slice-closure.md` gains delegated decisions, dates and numbers, retired types and real seeds, and two report lines.

## 0.1.0 — 2026-10-01

- First extraction from the reference project (sanam-al-ezz): governance instructions for the three phases, baseline template, decision-log and change-request templates, 14 engineering standards, architecture and ADR templates, module documentation package, 14 documentation quality gates, implementation-planning templates, quality-gate scripts with a config layer, the `laravel-react` stack profile, 35 numbered lessons, and four checklists.
- Project-specific content (modules, numbered decisions, measured figures) was deliberately not carried over.
