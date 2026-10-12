# Changelog — Shift SDF

All framework changes are recorded here. The framework obeys its own rules: a standard is never edited silently; every change carries a version and a reason.

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
