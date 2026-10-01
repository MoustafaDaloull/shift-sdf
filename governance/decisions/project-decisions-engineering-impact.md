---
document_type: Framework Template
framework: Shift SDF
file: governance/decisions/project-decisions-engineering-impact.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/00-product/project-decisions-engineering-impact.md
language: ar
generalization: reviewed
---

# قالب فهرس الأثر الهندسي — Engineering Impact Index

> **كيف يُستعمل:** يُنسخ إلى `docs/00-product/project-decisions-engineering-impact.md`. يُصنَّف حسب **النطاق الهندسي** لا حسب الموديول، ويتكامل مع `project-decisions-index.md` ولا يكرره.

## ترويسة الملف في المشروع

```yaml
---
document_type: Engineering Impact Index — Read-Only Derived Layer
project_name: {{PROJECT_NAME}}
document_version: "0.1"
document_status: Baseline
language: ar
owner: {{OWNER}}
last_updated: {{YYYY-MM-DD}}
source_file: docs/00-product/project-decisions.md
source_version: "{{إصدار السجل}}"
decision_ref: {{معرّف الخطوة}}
related_files:
  - docs/00-product/project-decisions-index.md
  - docs/00-product/identifier-alias-map.md
  - CLAUDE-ENGINEERING.md
---
```

---

# فهرس الأثر الهندسي لسجل القرارات — Engineering Impact Index

> **هذا الملف طبقة مشتقة للقراءة فقط، وليس مصدر حقيقة.**
>
> المرجع الوحيد المعتمد للقرارات هو `docs/00-product/project-decisions.md`. عند أي تعارض، تناقض، أو اختلاف في الصياغة بين هذا الفهرس والسجل المرجعي — **يسود السجل المرجعي دائمًا**، ويُصحَّح هذا الملف تبعًا له.
>
> **الغرض:** تمكين وكلاء الهندسة من تحديد أي قرارات منتج معتمدة في `project-decisions.md` يجب قراءتها **قبل** كتابة أي من المخرجات الهندسية التالية:
>
> - `data-model.md`
> - `api-contracts.md`
> - `user-stories.md`
> - `test-scenarios.md`
>
> **هذا الملف لا يُعرِّف أي سلوك هندسي جديد.** هو فقط يُحيل إلى قرارات موجودة فعليًا في `project-decisions.md`، مصنَّفة حسب **النطاق الهندسي** بدلًا من التصنيف حسب الموديول (كما في `project-decisions-index.md`). الملفان متكاملان لا متكرران:
>
> - `project-decisions-index.md` → «ما هي القرارات المتعلقة بـ MOD-NN؟»
> - `project-decisions-engineering-impact.md` (هذا الملف) → «ما هي القرارات التي يجب قراءتها قبل كتابة `api-contracts.md` لأي موديول؟»

---

## 0. كيفية الاستخدام

1. حدد المخرَج الهندسي الذي تنوي كتابته والموديول المستهدف.
2. ابحث عن القسم المطابق للنطاق الهندسي ذي الصلة في الجدول أدناه (§1).
3. اقرأ فقط نطاق الأسطر المحدد في عمود **Source** من `project-decisions.md` بقراءة مجزأة (`offset`/`limit`) — لا تقرأ الملف كاملًا.
4. تحقق من عمود **Status** قبل البناء على أي قرار:
   - `معتمد` → يمكن البناء عليه مباشرة.
   - `مفتوح` / `بانتظار مراجعة قانونية` / `بانتظار تأكيد تنظيمي` → **BLOCKED** — لا يُبنى عليه، ولا يُخترع حل بديل.
   - `مؤجَّل` → خارج نطاق المرحلة الحالية، يُعلَّم `OUT OF SCOPE` في المخرَج الهندسي.
   - `PROPOSED` → لا يُبنى عليه دون ADR.
   - `معدَّل` / `SUPERSEDED PARTIALLY` → اقرأ القرار الأصلي **و** القرار المعدِّل معًا؛ القرار المعدِّل يسود في نطاق التعديل فقط.
5. لكل قرار حساس (مال، صلاحية، ملكية، قانون) تحقق من القيد الوارد في عمود **Why** قبل تضمينه في `data-model.md` أو `api-contracts.md`.

---

## 1. الفهرس حسب النطاق الهندسي

> النطاقات أدناه قائمة ابتدائية؛ يُحذف ما لا ينطبق على المشروع ويُعلَن حذفه في سجل الإصدارات، ويُضاف نطاق جديد بترقيم تالٍ.

### 1.1 Engineering Governance — حوكمة الانتقال الهندسي

يشمل قرارات تحكم عملية توليد المخرجات الهندسية نفسها (لا محتواها الوظيفي). تنطبق على **جميع** المخرجات الهندسية دون استثناء.

| Decision ID | Status | Module(s) | Artifact(s) | Why | Source |
|---|---|---|---|---|---|
| {{DEC-ENG-...}} | {{معتمد}} | {{Project-wide}} | {{data-model, api-contracts, ...}} | {{لماذا يلزم قراءته قبل الكتابة — وما القيد الذي يفرضه}} | {{project-decisions.md: n–n}} |

### 1.2 Data Modeling — نمذجة البيانات
### 1.3 API Contracts — عقود الواجهات البرمجية
### 1.4 Authentication — المصادقة
### 1.5 Authorization — التفويض والصلاحيات
### 1.6 State Machines — آلات الحالة
### 1.7 Media and Files — الوسائط والملفات
### 1.8 Payments and Financial Transactions — المدفوعات والمعاملات المالية
### 1.9 Concurrency-Sensitive Operations — العمليات الحساسة للتزامن
### 1.10 Notifications — الإشعارات
### 1.11 Audit Logging — سجل التدقيق
### 1.12 External Integrations — التكاملات الخارجية
### 1.13 Cloud Infrastructure — البنية التحتية السحابية
### 1.14 Background Processing — المعالجة الخلفية
### 1.15 Security and Privacy — الأمان والخصوصية
### 1.16 Data Retention — الاحتفاظ بالبيانات
### 1.17 Localization — التعريب والتوطين
### 1.18 Testing — الاختبار
### 1.19 Release / Operations — الإطلاق والتشغيل

> كل نطاق يحمل الجدول نفسه بأعمدته الستة (`Decision ID | Status | Module(s) | Artifact(s) | Why | Source`).

---

## 2. القرارات المفتوحة ذات الأثر الحاجب (BLOCKED) — ملخص عابر للنطاقات

القرارات التالية **تحجب** أجزاءً من `data-model.md`/`api-contracts.md` في موديولات محددة. لا يجوز اختراع بديل لأي منها.

| Decision ID | الحالة | الموديول المتأثر | ما الذي يحجبه | المرجع |
|---|---|---|---|---|
| {{OD-NNN / DEC-...}} | {{مفتوح — ...}} | {{MOD-NN}} | {{الكيان أو العقد أو منطق آلة الحالة المحجوب}} | {{project-decisions.md: n}} |

---

## 3. تنبيه حوكمة إلزامي

- هذا الملف **مشتق وللقراءة فقط**. أي تحديث يجب أن يبدأ بتحديث `project-decisions.md` أولًا، ثم انعكاس الأثر هنا لاحقًا — وليس العكس.
- لا يجوز لوكيل هندسي الاستشهاد بهذا الملف كمصدر اعتماد لقرار — الاستشهاد الرسمي يكون دائمًا بمعرّف `DEC-*`/`OD-*` من `project-decisions.md` مباشرة.
- عند اكتشاف تعارض بين هذا الفهرس ومحتوى `project-decisions.md`، يُصحَّح هذا الملف فورًا ولا يُعتمد عليه في الأثناء.
- هذا الملف لا يُعفي أي وكيل هندسي من قراءة القرار الكامل في `project-decisions.md` قبل استخدامه — هو أداة **تحديد موقع** لا أداة **إحلال**.

---

## 4. سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| {{0.1}} | {{YYYY-MM-DD}} | {{الإصدار الأول — فهرس أثر هندسي مشتق فوق `project-decisions.md` v{{source_version}}، منظَّم حسب n نطاقًا هندسيًا}} | {{Baseline}} |
