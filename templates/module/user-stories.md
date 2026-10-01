---
document_type: Framework Template
framework: Shift SDF
file: templates/module/user-stories.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/01-modules/auctions/user-stories.md
language: ar
generalization: reviewed
---

# قالب — `user-stories.md` — قصص المستخدم

> **frontmatter الوثيقة عند الاستخدام:**

```yaml
---
module_id: {{MODULE_ID}}
module_code: {{MODULE_CODE}}
module_name_ar: {{MODULE_NAME}}
document_type: user-stories
document_version: "{{X.Y}}"
document_status: {{Draft | Approved}}
wave: "{{موجة التوثيق الهندسي}}"
last_updated: {{DATE}}
author: {{الدور الكاتب}}
source_artifact: engineering-input-analysis.md v{{X.Y}}, api-contracts.md v{{X.Y}}
---
```

## قواعد هذه الوثيقة

- المعرّف: `US-{{MODULE_CODE}}-NNN` — ثابت لا يُعاد ترقيمه. وتُجمَّع القصص في **مجموعات** (Epic / Capability) بالدور أو بمرحلة دورة الحياة.
- العنوان: `### US-{{MODULE_CODE}}-NNN — {{العنوان}} — P{{1|2|3}}`؛ ثم الصياغة: «بصفتي {{دورًا}}، أريد {{الهدف}}» (والقيمة إن لم تكن بديهية).
- معايير القبول: `AC-NNN-NN` (رقم القصة ثم تسلسل) — كل معيار قابل للاختبار ويحمل مرجعه (كود خطأ · `BR-*` · قرار). لا عبارة غير قابلة للقياس.
- القصة لا تخترع قاعدة عمل ولا سياسة؛ وتبقى داخل حدود الموديول والمرحلة.
- القصة النظامية (أحداث · تدقيق · نقل ملكية) تُكتب بصيغة تشغيلية مبرَّرة في مجموعة «النظام والأحداث».
- ملخص التغطية يُحسب فعليًا: كل FR وFlow وAPI وScreen وBR مغطًّى بقصة أو مبرَّر غيابه.
- تُراجَع بـ`user-stories-quality-gate.md` قبل بدء `test-scenarios.md`.

---

# User Stories — {{MODULE_ID}} ({{MODULE_CODE}})
# {{MODULE_NAME}}

---

## المجموعة 1 — {{اسم المجموعة}} ({{ROLE_A}})

### US-{{MODULE_CODE}}-001 — {{العنوان}} — P1
بصفتي {{دورًا}}، أريد {{الهدف}}.
- AC-001-01: {{معيار قابل للاختبار — مرجعه: ERR-{{MODULE_CODE}}-BIZ-NNN / BR-{{MODULE_CODE}}-NNN}}.
- AC-001-02: {{…}}.
- AC-001-03: {{يُنشأ بحالة {{STATE_A}} + إشعار … + تدقيق …}}.

### US-{{MODULE_CODE}}-002 — {{العنوان}} — P1
بصفتي {{دورًا}}، أريد {{الهدف}}.
- AC-002-01: {{…}}.
- AC-002-02: {{سجلاتي فقط (anti-leak 404)}}.

---

## المجموعة 2 — {{اسم المجموعة}} ({{ROLE_ADMIN}})

### US-{{MODULE_CODE}}-NNN — {{العنوان}} — P1
بصفتي {{ROLE_ADMIN}}، أريد {{الهدف}}.
- AC-NNN-01: {{…}}.
- AC-NNN-02: {{غير المخوَّل لا يصل (ERR-{{MODULE_CODE}}-AUZ-NNN)}}.

---

## المجموعة N — النظام والأحداث

### US-{{MODULE_CODE}}-NNN — {{الأثر التلقائي عند حدث}} — P1
{{صيغة تشغيلية: عند {{الحدث}} يُطلق النظام {{EVT-{{MODULE_CODE}}-NNN}} ويُسجَّل {{…}} في سجل التدقيق.}}
- AC-NNN-01: {{…}}.

---

## ملخص التغطية

| البُعد | التغطية |
|---|---|
| FR | {{N/N}} ({{100%}}) |
| Flow | {{N/N}} ({{100%}}) |
| API | {{N/N}} REST ({{100%}}) |
| Screen | {{N/N}} ({{100%}}) |
| BR | {{N/N}} ({{100%}}) |
| القصص | {{N}} ({{N}} P1 + {{N}} P2) |
| معايير القبول | ~{{N}} |

---

## سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| 1.0 | {{DATE}} | الإصدار الأول — {{N}} قصة في {{N}} مجموعات | Draft |
