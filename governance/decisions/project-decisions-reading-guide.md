---
document_type: Framework Template
framework: Shift SDF
file: governance/decisions/project-decisions-reading-guide.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/00-product/project-decisions-reading-guide.md
language: ar
generalization: reviewed
---

# قالب دليل القراءة الإلزامي لسجل القرارات — Decision Reading Guide

> **كيف يُستعمل:** يُنسخ إلى `docs/00-product/project-decisions-reading-guide.md`. يُقرأ في بداية أي مهمة هندسية قبل أي ملف آخر من طبقة الاسترجاع.

## ترويسة الملف في المشروع

```yaml
---
document_type: Decision Reading Guide — AI Agent Reference
project_name: {{PROJECT_NAME}}
document_version: "0.1"
document_status: Baseline
language: ar
owner: {{OWNER}}
source_file: docs/00-product/project-decisions.md
source_version: "{{إصدار السجل}}"
source_hash: {{git blob hash للسجل وقت البناء}}
last_updated: {{YYYY-MM-DD}}
decision_ref: {{معرّف الخطوة}}
---
```

---

# دليل القراءة الإلزامي لسجل القرارات — Decision Reading Guide (AI Agent Reference)

> **هذا الملف طبقة مشتقة للقراءة فقط — DERIVED READ-ONLY — وليس مصدر الحقيقة.**
>
> مصدر الحقيقة الوحيد هو: `docs/00-product/project-decisions.md`
>
> عند أي تعارض بين هذا الدليل وأي محتوى فعلي في السجل المرجعي، أو في أي من ملفات طبقة الاسترجاع (`project-decisions-index.md` وما يماثله)، **يسود السجل المرجعي دائمًا**. لا يجوز اعتبار هذا الدليل بديلاً عن قراءة القرار الأصلي، ولا استخدامه لاتخاذ قرار تجاري أو مالي أو قانوني أو خاص بالصلاحيات دون الرجوع إلى نص القرار كاملاً.
>
> **اللغة:** العربية هي اللغة الرئيسية لهذا الملف. تُستخدم الإنجليزية فقط للمعرّفات (`DEC-*`, `FR-*`, `BR-*`, `FLOW-*`, `SCR-*`, `AC-*`) وأسماء الملفات والمصطلحات التقنية عند الحاجة.
>
> **الجمهور المستهدف:** هذا الدليل مرجع رسمي مستقل موجّه حصرًا لوكلاء الذكاء الاصطناعي والمهندسين العاملين على المهام الهندسية ضمن مشروع {{PROJECT_NAME}} — وليس لمهام التحليل (Phase 0) التي يحكمها ملف تعليمات تلك المرحلة.

---

## §1 — تسلسل القراءة الإلزامي للمهام الهندسية

لأي مهمة هندسية (Data Model، API Contracts، User Stories، Test Scenarios، أو أي مخرج هندسي آخر)، اتبع الخطوات العشر التالية **بالترتيب** ولا تتخطَّ أيًا منها:

| الخطوة | الإجراء | الغرض |
|---|---|---|
| 1 | اقرأ `PROJECT-BASELINE.md` | حالة المشروع، مراجع الإصدارات، ملخص القرارات المفتوحة |
| 2 | اقرأ ملف تعليمات المرحلة الهندسية (`CLAUDE-ENGINEERING.md`) | قواعد المرحلة، منهجية الموجات، ترتيب أولوية المصادر |
| 3 | حدد الموديول الهدف ونوع المخرج المطلوب | استخدم `module-registry.md` لتثبيت هوية الموديول |
| 4 | اقرأ قسم الموديول في `project-decisions-index.md` (§2) | الحصول على نطاقات الأسطر للقراءة المجزأة المستهدفة |
| 5 | اقرأ `project-decisions-engineering-impact.md` لنطاق المخرج الهدف | حصر القرارات ذات الأثر الهندسي المباشر على نوع المخرج |
| 6 | اقرأ `project-decisions-open-worklist.md` | التحقق من وجود عوائق (Blockers) تمس الموديول أو المخرج الهدف |
| 7 | اقرأ `project-decisions-supersession-map.md` | التأكد من عدم استبدال أي قرار مُستخدَم كمرجع |
| 8 | استرجع كل قرار ذي صلة من `project-decisions.md` بقراءة مجزأة (`offset` + `limit`) | قراءة نص القرار الأصلي كاملاً دون تحميل الملف بأكمله |
| 9 | تحقق لكل قرار مسترجَع من: (أ) الحالة ما زالت سارية، (ب) نص القرار يطابق ما ورد في الفهرس، (ج) لا يوجد استبدال ينطبق عليه، (د) النطاق المتأثر يشمل الموديول أو المخرج الهدف فعليًا | ضمان صحة الاستناد قبل الاستخدام |
| 10 | ابدأ تأليف المخرج الهندسي فقط بعد اجتياز الخطوات 1–9 | منع البناء على قرار غير محقَّق أو مُستبدَل أو خارج النطاق |

**ملاحظة إلزامية:** لا يجوز تخطي الخطوة 9 حتى لو بدا القرار واضحًا من عنوانه في الفهرس. الفهرس أداة تنقل فقط، والتحقق يتم دائمًا من النص الأصلي في `project-decisions.md`.

---

## §2 — وصفات الاسترجاع الخاصة بكل مخرج (Artifact-Specific Reading Recipes)

كل وصفة أدناه تحدد فئات القرارات الواجب استرجاعها **قبل** البدء في كتابة المخرج المذكور. القرارات المذكورة أمثلة توجيهية إلزامية الفحص، ولا تُعفي من تنفيذ §1 كاملة، ولا من التحقق المنصوص عليه في الخطوة 9.

### قبل `engineering-input-analysis.md`
- {{فئات القرارات: حوكمة الانتقال الهندسي · حدود الموديول · البنود المفتوحة الحاجبة}}

### قبل `data-model.md`
- {{نمذجة البيانات · الاحتفاظ · الملكية العابرة · نوع المفتاح الأساسي · التعدادات}}

### قبل `api-contracts.md`
- {{عقود API · المصادقة · التفويض · آلات الحالة · عقد الأخطاء}}

### قبل `user-stories.md`
- {{قرارات السلوك والأدوار · ما أُلغي من أدوار أو مسارات}}

### قبل `test-scenarios.md`
- {{الاختبار · القيم القابلة للضبط · الحالات الحساسة (مال · صلاحية · ملكية)}}

---

## §3 — قواعد ميزانية السياق (Context Budget Rules)

يجب ألا يحتوي سياق العمل الهندسي الافتراضي إلا على:

- قرارات موديول هدف واحد فقط.
- القرارات العالمية ذات الصلة ({{DEC-ENG-* · DEC-ARCH-*}}).
- قرارات المعمارية ذات الصلة.
- قرارات الموديولات المعتمَد عليها مباشرة (Direct Dependencies من `module-registry.md`).
- القرارات المفتوحة المؤثرة على المخرج الهدف.
- النص الأصلي للقرارات المُستشهَد بها (مسترجَعًا عبر قراءة مجزأة).

**لا تُحمَّل:**

- قرارات موديولات غير ذات صلة.
- إدخالات الإصدارات التاريخية (سجل الإصدارات).
- القرارات المغلقة أو الملغاة، إلا للتحقق من الاستبدال (Supersession).
- أقسام جلسات الإغلاق الجماعية كاملةً، إلا إذا كان الموديول الهدف مذكورًا فيها صراحة.

**للعمل عبر عدة موديولات:** قسّم الاسترجاع حسب النطاق (Domain) باستخدام `project-decisions-engineering-impact.md`.

**تنبيه حرج:** لا تعتبر القراءة الجزئية للسجل دليلاً على عدم وجود قرار. عند الشك، ابحث (`grep`) عن معرّف القرار أو الكلمة المفتاحية مباشرة في `project-decisions.md`.

---

## §4 — قالب سياق القرار الموحّد (Standard Decision Context Block)

يجب على كل وكيل هندسي إنتاج الكتلة التالية قبل تأليف أي مخرج هندسي:

```text
DECISION CONTEXT

Target Module: [MOD-NN — Module Name]
Target Artifact: [data-model / api-contracts / user-stories / test-scenarios]
Source Registry Version: [vX.Y]
Source Registry Hash: [git blob hash]

Direct Decisions: [list of DEC-* IDs retrieved for the target module]
Global Decisions: [DEC-ENG-*, DEC-ARCH-*, etc.]
Cross-Module Decisions: [decisions from dependency modules]
Architecture Decisions: [APPROVED items from the architecture decision]
Open Decisions: [any OPEN/DEFERRED affecting the target]
Superseded Decisions: [any referenced decision that has been cancelled/replaced]
Unresolved References: [any decision ID referenced but not found or not verified]
```

**ملاحظة:** `Source Registry Hash` هو git blob hash للسجل وقت بناء هذا الدليل (`git hash-object docs/00-product/project-decisions.md`). أي تعديل لاحق على الملف المرجعي يغيّر هذه القيمة، ويجب على الوكيل التحقق من القيمة الفعلية عند الاستخدام بدلاً من افتراض ثباتها.

---

## §5 — خريطة ملفات طبقة استرجاع القرارات (Decision Retrieval Layer File Map)

| الملف | الغرض | متى يُقرأ |
|---|---|---|
| `project-decisions-index.md` | خريطة الأقسام + دليل البحث عن الموديول + عائلات المعرّفات | دائمًا — نقطة التنقل الأولى |
| `project-decisions-by-status.md` | القرارات مصنّفة حسب الحالة | عند التحقق من كون القرار ما زال ساريًا |
| `project-decisions-engineering-impact.md` | القرارات حسب النطاق الهندسي | عند بدء نوع مخرج هندسي محدد |
| `project-decisions-open-worklist.md` | القرارات المفتوحة/المؤجلة/المقترحة | عند التحقق من العوائق |
| `project-decisions-supersession-map.md` | علاقات الاستبدال بين القرارات | عند التحقق من عدم استبدال قرار |
| `project-decisions-reading-guide.md` | هذا الملف — تسلسل القراءة والوصفات | في بداية أي مهمة هندسية |

> **حالة التوفر:** {{تُذكر هنا الملفات المبنيّة فعلًا من الستة؛ الغائب يُعلَن ولا يُفترض}}.

---

## §6 — سجل الإصدارات

| الإصدار | التاريخ | الوصف | المرجع |
|---|---|---|---|
| {{0.1}} | {{YYYY-MM-DD}} | {{الإصدار الأولي — دليل القراءة الإلزامي لسجل القرارات}} | {{decision_ref}} |
