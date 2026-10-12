// =============================================================================
// GATE-I18N — the client app's translation gate (Shift SDF)
// -----------------------------------------------------------------------------
// Runs INSIDE the node container (the toolchain lives in the image, and the
// frontend is mounted at NODE_WORKDIR). quality.sh pipes this file to `node -`
// with two assignments prepended:
//
//   globalThis.SHIFT_I18N          — the gate's config (from scripts/config/shift.env)
//   globalThis.SHIFT_I18N_BASELINE — the committed per-file literal baseline
//
// so nothing is copied into the container and the gate reads exactly the
// files in the working tree.
//
// Three checks, all must pass:
//
//   (a) KEY PARITY — every key in <locales>/<primary>/*.json exists in
//       <locales>/<secondary>/*.json and vice versa (file name = namespace,
//       nested keys flattened with dots), every value is a string, every
//       message parses as ICU, and both languages use the same set of
//       {placeholders} (and rich-text <tags>) per key; and no primary-language
//       message formats a number or a date through ICU (`#`, number/date/time)
//       — locale data for the primary language differs between browsers, so
//       the value is passed as text and inserted as given.
//
//   (b) LITERAL RATCHET — walks the client app's import graph from its entry
//       points and counts, per file, the string literals, template literals
//       and JSX text that contain primary-language letters. Comments are never
//       read. A file whose count is HIGHER than the baseline, or a file absent
//       from the baseline with any literal, fails the gate. Lower counts pass
//       and are reported, so later slices refresh the baseline downwards:
//           bash scripts/i18n/refresh-baseline.sh
//
//   (c) ONE SENTENCE = ONE KEY — in the client files, a sentence must not be
//       assembled from several translation calls around a link, an emphasis
//       or a value. Within one JSX element, a run of inline children (text,
//       values, <Link>/<a>/<b>/<strong>/<em>/<span>/<bdi>/<br>…) that holds
//       two or more translated pieces, at least one of them a bare {t(…)},
//       fails; so do `t(…) + … + t(…)` and a template literal holding two
//       t(…) calls. The sentence becomes one rich message with tags and
//       {placeholders} (38 sentences = 99 broken pieces in the reference
//       project before this rule). No baseline: the count must be zero.
//
// Modes:
//   (default)          run the checks; exit 1 on any failure
//   --print-counts     print the per-file counts as baseline JSON; exit 0
//
// Dependencies (devDependencies of the frontend): `typescript` and
// `@formatjs/icu-messageformat-parser`. A missing one is red, never a pass.
// =============================================================================
'use strict'

const fs = require('fs')
const path = require('path')
const { createRequire } = require('module')

const CFG = Object.assign(
  {
    src: 'src',
    locales: 'src/i18n/locales',
    primary: 'ar',
    secondary: 'en',
    entries: 'modules/*/client/routes.tsx app/routes.tsx app/ClientLayout.tsx',
    excludeRegex: '',
    translateFn: 't',
  },
  globalThis.SHIFT_I18N || {},
)

const APP = process.cwd()
const ROOT = path.resolve(APP, CFG.src)
const LOCALES = path.resolve(APP, CFG.locales)
const appRequire = createRequire(`${APP}/package.json`)

let ts
let parseIcu
try {
  ts = appRequire('typescript')
  parseIcu = appRequire('@formatjs/icu-messageformat-parser').parse
} catch (e) {
  console.log(`  ✗ اعتمادية البوابة غائبة — ثبّت typescript و@formatjs/icu-messageformat-parser في الواجهة (${e.message})`)
  process.exit(1)
}

// Letters of the primary language. Arabic script by default; extend the map
// when a project's primary language is written in another script.
const SCRIPTS = {
  ar: /[؀-ۿ]/,
  fa: /[؀-ۿ]/,
  ur: /[؀-ۿ]/,
  he: /[֐-׿]/,
  ru: /[Ѐ-ӿ]/,
  el: /[Ͱ-Ͽ]/,
}
const PRIMARY = SCRIPTS[CFG.primary]
if (!PRIMARY) {
  console.log(`  ✗ لا نمط حروف معروف للّغة الأساسية «${CFG.primary}» — أضفه إلى SCRIPTS في scripts/i18n/i18n-check.cjs`)
  process.exit(1)
}

const MODE = process.argv.includes('--print-counts') ? 'print' : 'check'
const EXCLUDE = CFG.excludeRegex ? new RegExp(CFG.excludeRegex) : null

// ── (b) the client-reachable file set ───────────────────────────────────────

// Entry globs support a single `*` segment (one directory level), which is
// what module layouts need; anything more is a config smell, not a feature.
function expandEntry(pattern) {
  const parts = pattern.split('/')
  let acc = [ROOT]
  for (const part of parts) {
    const next = []
    for (const base of acc) {
      if (part === '*') {
        if (fs.existsSync(base) && fs.statSync(base).isDirectory()) {
          for (const d of fs.readdirSync(base)) next.push(path.join(base, d))
        }
      } else {
        next.push(path.join(base, part))
      }
    }
    acc = next
  }
  return acc.filter((f) => fs.existsSync(f) && fs.statSync(f).isFile())
}

const entries = CFG.entries.split(/\s+/).filter(Boolean).flatMap(expandEntry)
if (entries.length === 0) {
  console.log(`  ✗ لا نقطة دخول للعميل تطابق I18N_CLIENT_ENTRIES («${CFG.entries}») تحت ${path.relative(APP, ROOT)}`)
  process.exit(1)
}

const isExcluded = (f) => EXCLUDE !== null && EXCLUDE.test(f.replace(/\\/g, '/'))

function resolveImport(from, spec) {
  if (!spec.startsWith('.')) return null
  const base = path.resolve(path.dirname(from), spec)
  for (const c of [base, `${base}.ts`, `${base}.tsx`, `${base}/index.ts`, `${base}/index.tsx`]) {
    if (fs.existsSync(c) && fs.statSync(c).isFile()) return c
  }
  return null
}

const parseSource = (f) =>
  ts.createSourceFile(
    f,
    fs.readFileSync(f, 'utf8'),
    ts.ScriptTarget.Latest,
    true,
    f.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
  )

function clientFiles() {
  const seen = new Set()
  const queue = [...entries]
  while (queue.length) {
    const f = queue.pop()
    if (seen.has(f)) continue
    if (isExcluded(f) && !entries.includes(f)) continue
    if (!/\.tsx?$/.test(f)) continue
    seen.add(f)
    const visit = (n) => {
      if ((ts.isImportDeclaration(n) || ts.isExportDeclaration(n)) && n.moduleSpecifier && ts.isStringLiteral(n.moduleSpecifier)) {
        const r = resolveImport(f, n.moduleSpecifier.text)
        if (r) queue.push(r)
      }
      if (ts.isCallExpression(n) && n.expression.kind === ts.SyntaxKind.ImportKeyword && n.arguments[0] && ts.isStringLiteral(n.arguments[0])) {
        const r = resolveImport(f, n.arguments[0].text)
        if (r) queue.push(r)
      }
      ts.forEachChild(n, visit)
    }
    visit(parseSource(f))
  }
  return [...seen].sort()
}

function countLiterals(f) {
  let count = 0
  const visit = (n) => {
    if (ts.isImportDeclaration(n)) return
    if (ts.isStringLiteral(n) || ts.isNoSubstitutionTemplateLiteral(n)) {
      if (PRIMARY.test(n.text)) count++
      return
    }
    if (ts.isTemplateExpression(n)) {
      const literal = n.head.text + n.templateSpans.map((s) => s.literal.text).join('')
      if (PRIMARY.test(literal)) {
        count++
        // The spans' expressions may hold literals of their own.
        n.templateSpans.forEach((s) => visit(s.expression))
        return
      }
    }
    if (ts.isJsxText(n)) {
      if (PRIMARY.test(n.text)) count++
      return
    }
    ts.forEachChild(n, visit)
  }
  visit(parseSource(f))
  return count
}

const rel = (f) => path.relative(APP, f).replace(/\\/g, '/')

function literalCounts() {
  const counts = {}
  for (const f of clientFiles()) {
    const c = countLiterals(f)
    if (c > 0) counts[rel(f)] = c
  }
  return counts
}

if (MODE === 'print') {
  const counts = literalCounts()
  const sorted = Object.fromEntries(Object.keys(counts).sort().map((k) => [k, counts[k]]))
  process.stdout.write(`${JSON.stringify(sorted, null, 2)}\n`)
  process.exit(0)
}

const failures = []

// ── (a) key parity ──────────────────────────────────────────────────────────

function flatten(tree, prefix, into, file) {
  for (const [key, value] of Object.entries(tree)) {
    const k = `${prefix}.${key}`
    if (typeof value === 'string') into.set(k, value)
    else if (value !== null && typeof value === 'object' && !Array.isArray(value)) flatten(value, k, into, file)
    else failures.push(`${file}: «${k}» ليست نصًّا ولا كائنًا`)
  }
}

function loadLocale(locale) {
  const dir = path.join(LOCALES, locale)
  const out = new Map()
  if (!fs.existsSync(dir)) {
    failures.push(`مجلد اللغة غائب: ${rel(dir)}`)
    return out
  }
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith('.json')).sort()) {
    const file = rel(path.join(dir, name))
    let tree
    try {
      tree = JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'))
    } catch (e) {
      failures.push(`${file}: JSON غير صالح — ${e.message}`)
      continue
    }
    flatten(tree, name.replace(/\.json$/, ''), out, file)
  }
  return out
}

function argumentsOf(elements, into) {
  for (const el of elements) {
    if (el.type >= 1 && el.type <= 6) into.add(el.value)
    if (el.type === 8) {
      into.add(`<${el.value}>`)
      argumentsOf(el.children || [], into)
    }
    if (el.options) for (const opt of Object.values(el.options)) argumentsOf(opt.value, into)
  }
  return into
}

function placeholders(locale, key, message) {
  try {
    return argumentsOf(parseIcu(message), new Set())
  } catch (e) {
    failures.push(`${locale}: «${key}» رسالة ICU غير صالحة — ${e.message}`)
    return null
  }
}

const primary = loadLocale(CFG.primary)
const secondary = loadLocale(CFG.secondary)
let keyFailures = 0
for (const k of primary.keys()) if (!secondary.has(k)) { failures.push(`مفتاح في ${CFG.primary} وغائب عن ${CFG.secondary}: ${k}`); keyFailures++ }
for (const k of secondary.keys()) if (!primary.has(k)) { failures.push(`مفتاح في ${CFG.secondary} وغائب عن ${CFG.primary}: ${k}`); keyFailures++ }
// A primary-language message must never format a number or a date through
// ICU: `#` inside a plural, `{x, number}`, `{x, date}` and `{x, time}` follow
// the browser's locale data, which differs between browsers (Arabic-Indic
// digits in some, grouping commas in others). Plain `{x}` is inserted as text
// and stays allowed.
const formatsValues = (elements) => elements.some((el) =>
  el.type === 2 || el.type === 3 || el.type === 4 || el.type === 7 ||
  (el.children && formatsValues(el.children)) ||
  (el.options && Object.values(el.options).some((opt) => formatsValues(opt.value))))
for (const [k, message] of primary) {
  try {
    if (formatsValues(parseIcu(message))) {
      failures.push(`رسالة باللغة الأساسية تنسّق رقمًا أو تاريخًا عبر ICU («#» أو number/date/time) — مرّر القيمة نصًّا: ${k}`)
      keyFailures++
    }
  } catch { /* reported below by placeholders() */ }
  if (!secondary.has(k)) continue
  const a = placeholders(CFG.primary, k, message)
  const b = placeholders(CFG.secondary, k, secondary.get(k))
  if (a === null || b === null) { keyFailures++; continue }
  const same = a.size === b.size && [...a].every((x) => b.has(x))
  if (!same) {
    failures.push(`المتغيّرات تختلف في «${k}»: ${CFG.primary} {${[...a].sort().join(', ')}} · ${CFG.secondary} {${[...b].sort().join(', ')}}`)
    keyFailures++
  }
}
console.log(`(أ) تطابق المفاتيح: ${primary.size} مفتاحًا (${CFG.primary}) · ${secondary.size} (${CFG.secondary}) — ${keyFailures === 0 ? 'مطابق' : `${keyFailures} خرق`}`)

// ── (b) the ratchet ─────────────────────────────────────────────────────────

const baseline = globalThis.SHIFT_I18N_BASELINE
if (baseline === undefined || baseline === null || typeof baseline !== 'object') {
  failures.push('الأساس غائب — شغّل عبر bash scripts/quality.sh i18n')
} else {
  const counts = literalCounts()
  let raised = 0
  let lowered = 0
  let total = 0
  for (const [file, c] of Object.entries(counts)) {
    total += c
    const allowed = baseline[file]
    if (allowed === undefined) {
      failures.push(`نص باللغة الأساسية في ملف خارج الأساس: ${file} (${c})`)
      raised++
    } else if (c > allowed) {
      failures.push(`زاد النص الحرفي في ${file}: ${c} > ${allowed}`)
      raised++
    } else if (c < allowed) {
      lowered++
    }
  }
  for (const file of Object.keys(baseline)) if (counts[file] === undefined) lowered++
  const baseTotal = Object.values(baseline).reduce((s, n) => s + n, 0)
  console.log(`(ب) سقف النص الحرفي: ${Object.keys(counts).length} ملفًّا · ${total} موضعًا (الأساس ${baseTotal}) — ${raised === 0 ? 'لا زيادة' : `${raised} ملفًّا فوق السقف`}`)
  if (lowered > 0 && raised === 0) {
    console.log(`    ${lowered} ملفًّا تحت سقفه — حدّث الأساس: bash scripts/i18n/refresh-baseline.sh`)
  }
}

// ── (c) one sentence = one key ──────────────────────────────────────────────

const INLINE_TAGS = /^(a|Link|NavLink|b|strong|em|i|u|small|mark|span|bdi|bdo|code|time|abbr|br|sup|sub)$/
const T = CFG.translateFn
const isT = (e) => e && ts.isCallExpression(e) && ts.isIdentifier(e.expression) && e.expression.text === T
const holdsT = (n) => {
  let found = false
  const visit = (x) => { if (found) return; if (isT(x)) { found = true; return } ts.forEachChild(x, visit) }
  visit(n)
  return found
}
const tagName = (c, sf) => (ts.isJsxElement(c) ? c.openingElement.tagName : c.tagName).getText(sf)

function splitSentences(f) {
  const sf = parseSource(f)
  const found = []
  const line = (n) => sf.getLineAndCharacterOfPosition(n.getStart(sf)).line + 1
  const visit = (n) => {
    if (ts.isJsxElement(n) || ts.isJsxFragment(n)) {
      let pieces = 0
      let bare = 0
      let start = null
      const close = () => {
        if (pieces >= 2 && bare >= 1) found.push(line(start))
        pieces = 0; bare = 0; start = null
      }
      for (const c of n.children) {
        if (ts.isJsxText(c)) continue
        if (ts.isJsxExpression(c)) {
          if (!c.expression) continue
          if (isT(c.expression)) { pieces++; bare++; start = start || c }
          continue // a value: part of the run
        }
        if ((ts.isJsxElement(c) || ts.isJsxSelfClosingElement(c)) && INLINE_TAGS.test(tagName(c, sf))) {
          if (holdsT(c)) { pieces++; start = start || c }
          continue
        }
        close() // a block element or a component ends the run
      }
      close()
    }
    if (ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.PlusToken &&
        !(ts.isBinaryExpression(n.parent) && n.parent.operatorToken.kind === ts.SyntaxKind.PlusToken)) {
      const parts = []
      const flat = (e) => { if (ts.isBinaryExpression(e) && e.operatorToken.kind === ts.SyntaxKind.PlusToken) { flat(e.left); flat(e.right) } else parts.push(e) }
      flat(n)
      if (parts.filter(isT).length >= 2) found.push(line(n))
    }
    if (ts.isTemplateExpression(n) && n.templateSpans.filter((s) => isT(s.expression)).length >= 2) found.push(line(n))
    ts.forEachChild(n, visit)
  }
  visit(sf)
  return found
}

{
  let split = 0
  for (const f of clientFiles()) {
    for (const l of splitSentences(f)) {
      failures.push(`جملة مقسّمة على أكثر من مفتاح (اجعلها رسالة غنية واحدة بوسوم ومتغيّرات): ${rel(f)}:${l}`)
      split++
    }
  }
  console.log(`(ج) جملة واحدة = مفتاح واحد: ${split === 0 ? 'لا جملة مقسّمة' : `${split} جملة مقسّمة`}`)
}

if (failures.length > 0) {
  for (const f of failures) console.log(`  ✗ ${f}`)
  process.exit(1)
}
