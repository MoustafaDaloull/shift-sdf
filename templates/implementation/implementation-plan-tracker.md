---
document_type: Framework Template
framework: Shift SDF
file: templates/implementation/implementation-plan-tracker.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/03-development/implementation/implementation-plan-tracker.md
language: ar
generalization: reviewed
---

# قالب — `implementation-plan-tracker.md` — متتبع خطة التنفيذ

> **frontmatter الوثيقة عند الاستخدام:**

```yaml
---
document_type: Implementation Plan Tracker
document_title: متتبع خطة التنفيذ — المصدر المركزي الوحيد للحالة
project_name: {{PROJECT_NAME}}
document_version: "{{X.Y}}"
document_status: {{Draft — Pending Product Owner Approval | Approved}}
language: ar
owner: {{OWNER}}
created_at: {{DATE}}
last_verified_commit: {{COMMIT}}
last_verified_date: {{DATE}}
---
```

## قواعد هذه الوثيقة

- **المصدر المركزي الوحيد لحالة التنفيذ.** لا تُكتب حالة تنفيذ في أي ملف آخر؛ ما يظهر في غيره إحالة إلى هنا.
- **`Last Verified Commit` حقل حاكم:** كل حالة فيه مقيسة على ذلك الالتزام. يُحدَّث مع كل تغيير حالة، والقياسات السابقة تُبقى تحته **سجلًّا تاريخيًّا لا حالةً حاليّة** ولا تُحذف.
- **قاعدة التقادم:** صفٌّ `DONE` أو `PASS` والالتزام الحالي غير `Last Verified Commit` ولم يُعَد التحقق ⟵ `STALE — REVERIFY` حتى إعادة القياس.
- **لا حالة بلا دليل:** كل `DONE` وكل `PASS` يُحيل إلى `EV-NNNN` في سجل الأدلة بأمرٍ يُعيد إنتاج النتيجة. الرقم المنقول من رسالة التزام أو من ملف آخر ليس دليلًا.
- **البوابة المُوقفة بقرار** تُكتب `SUSPENDED` بمرجع قرارها، لا `PASS` ولا `N/A` ولا تُسقط صامتًا. و**البوابة المحجوبة بسبب خارجي** تُكتب `BLOCKED` لا «أخضر».
- التواريخ `YYYY-MM-DD`. والنِّسب — إن استُخدمت — من عناصر DoD المستوفاة وحدها.
- الأعمدة لا تُحذف؛ غير المنطبق يُكتب `N/A` بسببه.

---

# متتبع خطة التنفيذ

> **`Last Verified Commit`: `{{COMMIT}}`** — *{{وصف البصمة: الفرع · آخر دمج · رقم تشغيل CI الأخضر عليها}}. والقياسُ السابق كان `{{COMMIT_PREV}}`.*
> **`Last Verified Date`: `{{DATE}}`**
>
> *(وما يلي قياسُ `{{COMMIT_PREV}}` سجلًّا تاريخيًّا لا حالةً حاليّة:)*
>
> **`Last Verified Commit` السابق: `{{COMMIT_PREV}}`** — *{{وصفه}}*
> **`Last Verified Date`: `{{DATE_PREV}}`**

---

## 1. الحالات المعتمدة

### 1.1 حالات العمل

```text
NOT_STARTED · READY · IN_PROGRESS · BLOCKED · IN_REVIEW · READY_FOR_QA
QA_IN_PROGRESS · READY_FOR_UAT · UAT_IN_PROGRESS · DONE · DEFERRED · N/A
STALE — REVERIFY   (تُلحق بأي DONE/PASS تقادم التزامُه بلا إعادة تحقق)
```

### 1.2 حالات بوابات الجودة

```text
NOT_RUN · PASS · FAIL · BLOCKED · SUSPENDED · N/A
```

> `NOT_IMPLEMENTED` تُستعمل حصرًا لبوابة **غير موجودة أصلًا**، وهي ليست حالة تشغيل بل حالة وجود.
> `SUSPENDED` لبوابة **مبنيّة ومُوقفة عن التسلسل بقرار مرقَّم** — تعمل بأمرها المفرد وتُعلن نفسها في كل تشغيلة.
> `BLOCKED` لبوابة **لا تستطيع التشغيل لسبب خارجي** (حصة · بيئة) — لا تُقرأ خضراء ولا `N/A`.

### 1.3 حالات القرارات

```text
NONE · OPEN · PROPOSED · APPROVED · DEFERRED · BLOCKING
```

### 1.4 الحالة التنفيذية للموديول

```text
NOT_STARTED · FOUNDATION_ONLY · PARTIALLY_IMPLEMENTED · BACKEND_IN_PROGRESS
FRONTEND_IN_PROGRESS · INTEGRATION_IN_PROGRESS · READY_FOR_QA · READY_FOR_UAT
DONE · BLOCKED · DEFERRED
```

---

## 2. جدول الموديولات الرئيس

> قياس الأساس لهذا الجدول على `{{COMMIT}}` (`EV-NNNN`..`EV-NNNN`)، لا مقدَّرًا؛ والصفوف المُعاد قياسها لاحقًا تحمل أدلتها الأحدث في خلاياها.
> `Readiness` = حالة الحزمة الهندسية · `Overall` = الحالة التنفيذية.

| Order | Wave | Module | Readiness | DB | Backend | API | Frontend | Integration | Tests | Security | Visual Parity | OpenAPI | CI | Overall | Blockers | Next Action |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `W-NN` | MOD-NN {{CODE}} | `{{DEVELOPMENT READY}}` | `{{NOT_STARTED}}` (`EV-NNNN`) | `{{…}}` | `{{N/N}}` | `{{…}}` | `{{…}}` | `{{…}}` | `{{…}}` | `{{…}}` | `{{…}}` | `{{PASS}}` (`{{RUN_ID}}`) | `{{NOT_STARTED}}` | `BLK-NN` | {{الشريحة التالية}} |

---

## 3. جدول الشرائح

> كل شريحة تُردّ إلى معرّفات مصدرية (`ENT-*`/`API-*`/`US-*`/`TS-*`/`SCR-*`) في عمود `Scope`؛ شريحة بلا معرّف مصدري نطاق مُخترَع.

| Slice ID | Module | Slice | Scope | Dependencies | Owner | Status | Started | Target | Completed | Quality Gates | Blockers | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `SL-{{CODE}}-01` | MOD-NN | {{اسم الشريحة}} | `ENT-{{CODE}}-NNN` · `API-{{CODE}}-NNN` · `US-{{CODE}}-NNN` · `TS-{{CODE}}-NNN` | {{SL-… · عقد …}} | {{الدور}} | `{{NOT_STARTED}}` | {{DATE}} | {{DATE}} | {{DATE}} | `QG-…` **`PASS`** · مُثبَتة بخرق متعمَّد | `BLK-NN` | `EV-NNNN` · `EV-NNNN` |

---

## 4. جدول المكوّنات

> تُفصَّل مكوّنات الشريحة عند بدئها لا قبله. النوع من القائمة المعتمدة في `definition-of-done.md §3`.

| Component ID | Slice ID | Type | Reference IDs | Description | Status | Test Evidence | Review Evidence |
|---|---|---|---|---|---|---|---|
| `CMP-{{CODE}}-001` | `SL-{{CODE}}-01` | `{{MIGRATION}}` + `{{MODEL}}` | `ENT-{{CODE}}-001` | `{{code}}_{{table}}` · {{موجز}} | `{{DONE}}` | `{{TST-CODE-01}}` / `EV-NNNN` | التزام `{{COMMIT}}` |

---

## 4B. الشريحة التأسيسية — بنودها مقابل قرار تعريفها

> يُستعمل حين يعرّف المشروع شريحة تأسيسية بقرار يسرد بنود إغلاقها. كل بند بحالته ودليله؛ والإغلاق يُعتمد بقرار منفصل يسجَّل هنا.

| # | البند | الحالة | الدليل |
|---|---|---|---|
| 1 | {{البند كما في القرار}} | `{{DONE}}` | `EV-NNNN` |

---

## 5. سجل الحواجب

> Blocker لا يُغلق بوجود توصية — يُغلق بقرار مسجَّل أو بدليل تنفيذي. والصفّ المُغلق يبقى بشطب لا بحذف.

| Blocker ID | Scope | Severity | Description | Source | Owner | Required Decision | Status | Resolution Evidence |
|---|---|---|---|---|---|---|---|---|
| `BLK-01` | {{المشروع · MOD-NN}} | **{{Critical}}** | {{ما يحجبه}} | {{الوثيقة §n · DEC-ID}} | مالك المنتج | {{القرار المطلوب}} | `{{OPEN}}` | {{— أو ✅ `CLOSED` DATE — DEC-ID · EV-NNNN}} |

---

## 6. سجل الأدلة

> **دليل غير قابل لإعادة التنفيذ ليس دليلًا.** الأمر حرفيًّا، والناتج مختصرًا، والالتزام الذي قيس عليه. أنواع الدليل: `COMMAND` · `FILE` · `CI_RUN` · `SCREENSHOT` · `REPORT` · `BREACH`.

| Evidence ID | Scope | Type | Command/File/URL | Result | Date | Commit |
|---|---|---|---|---|---|---|
| `EV-0001` | `SL-{{CODE}}-01` | `COMMAND` | `bash scripts/quality.sh --with-tests; echo EXIT=$?` | **`EXIT=0`** — {{N}} بوابة خضراء بتشغيل واحد · {{N}} مُوقفة بقرار مُعلَنة | {{DATE}} | `{{COMMIT}}` |
| `EV-0002` | `SL-{{CODE}}-01` | `CI_RUN` | {{رقم التشغيل}} | **`PASS`** — أو **`NOT_RUN` ولا يُدَّعى** | {{DATE}} | `{{COMMIT}}` |
| `EV-0003` | `QG-{{NAME}}` | `BREACH` | {{الخرق المتعمَّد وأمره}} | **البوابة احمرّت على الخرق** — `EXIT=1` · ثم استعادة | {{DATE}} | `{{COMMIT}}` |

---

## 7. قواعد التتبع الملزِمة

1. **لا `DONE` بلا Evidence.**
2. **لا نسبة إنجاز تخيلية** — وإن استُخدمت فمن عناصر DoD وحدها.
3. **موديول محجوب لا يظهر `IN_PROGRESS`** بلا تفسير في سجل الحواجب.
4. **لا يُغلق Blocker بوجود توصية** — يُغلق بقرار مسجَّل أو دليل تنفيذي.
5. **التواريخ `YYYY-MM-DD`.**
6. **الحالة تعكس المستودع وقت القياس** — و`Last Verified Commit` أعلى الملف هو مرجعها.
7. **أي حالة تتقادم عند تغيّر الالتزام دون إعادة تحقق ⟵ `STALE — REVERIFY`.**

---

## 8. سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| 1.0 | {{DATE}} | الإصدار الأول — قياس الأساس على `{{COMMIT}}` | Draft — بانتظار اعتماد مالك المنتج |
