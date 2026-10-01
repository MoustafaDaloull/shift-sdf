---
document_type: Framework Template
framework: Shift SDF
file: templates/module/traceability-matrix.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/01-modules/auctions/traceability-matrix.md
language: ar
generalization: reviewed
---

# قالب — `traceability-matrix.md` — مصفوفة التتبع

> **frontmatter الوثيقة عند الاستخدام:**

```yaml
---
module_id: {{MODULE_ID}}
module_code: {{MODULE_CODE}}
module_name_ar: {{MODULE_NAME}}
document_type: traceability-matrix
document_version: "{{X.Y}}"
document_status: {{Draft | Approved}}
wave: "{{موجة التوثيق الهندسي}}"
last_updated: {{DATE}}
author: {{الدور الكاتب}}
prerequisite:
  - engineering-input-analysis.md v{{X.Y}}
  - data-model.md v{{X.Y}}
  - api-contracts.md v{{X.Y}}
  - user-stories.md v{{X.Y}}
  - test-scenarios.md v{{X.Y}}
derived_from:
  - requirements.md v{{X.Y}} ({{N}} FR)
  - business-rules.md v{{X.Y}} ({{N}} BR)
  - user-flows.md ({{N}} FLOW)
  - screen-inventory.md ({{N}} شاشة)
  - permission-matrix.md
---
```

## قواعد هذه الوثيقة

- **لا تسكّ معرّفًا** — تربط ما سُكّ في الوثائق السابقة، وتُكتب آخر الحزمة الهندسية.
- ثمانية أبعاد تتبع إلزامية: `FR → All` · `BR → TS` · `Flow → All` · `Screen → All` · `API → All` · `Table → All` · `State Machine → BR/TS` · إحصائيات التغطية الإجمالية. والنسبة في كل بُعد تُحسب لا تُقدَّر.
- عنصر بلا صفّ = فجوة تُسجَّل في §9 (ملاحظات) بتصنيفها، لا تُخفى بنسبة 100% مجمَّلة.
- **طبقة التنفيذ** (§10 فما بعد): لكل شريحة تنفيذ قسم «التنفيذ ⟵ المعرّف الهندسي» يربط كل مكوّن كود (`CMP-{{MODULE_CODE}}-NNN`) بالمعرّف الهندسي الحاكم ومرجعه، مع قسمَين ثابتين: **«ما لم يُبنَ عمدًا وسندُه»** (البند · السبب · المعيار المتأثر) و**التعارضات المُستجدّة** التي تُرفع ولا تُحسم. هذا القسم هو دليل بند التتبع في تعريف إنجاز الشريحة.
- التعارض بين الكود والوثيقة يُسجَّل هنا بمعرّفه (`CFL-NN`) ويُرفع؛ لا تُعدَّل الوثيقة ولا يُكتب كود يخالفها صمتًا.
- تُراجَع ضمن `development-readiness-quality-gate.md`.

---

# Traceability Matrix — {{MODULE_ID}} ({{MODULE_CODE}})
# {{MODULE_NAME}}

> {{مدخل غير مقروء آليًا — إن وُجد: مراجعة يدوية مطلوبة}}

---

## 1. تتبع المتطلبات (FR → All) — {{N/N}}

| FR | الوصف | BR | Flow | Screen | API | US | TS | الحالة |
|---|---|---|---|---|---|---|---|---|
| FR-{{MODULE_CODE}}-001..NNN | {{المجموعة}} | BR-{{MODULE_CODE}}-NNN | FLOW-{{MODULE_CODE}}-NNN | SCR-{{MODULE_CODE}}-NNN | API-{{MODULE_CODE}}-NNN | US-{{MODULE_CODE}}-NNN | TS-{{MODULE_CODE}}-NNN | {{✅ | فجوة}} |

---

## 2. تتبع قواعد العمل (BR → TS) — {{N/N}}

| المحور | BR | TS |
|---|---|---|
| {{المحور}} | BR-{{MODULE_CODE}}-001..NNN | TS-{{MODULE_CODE}}-NNN..NNN |

---

## 3. تتبع التدفقات (Flow → All) — {{N/N}}

| Flow | الوصف | FR | Screen | API | TS | الحالة |
|---|---|---|---|---|---|---|
| FLOW-{{MODULE_CODE}}-001 | {{…}} | FR-{{MODULE_CODE}}-NNN | SCR-{{MODULE_CODE}}-NNN | API-{{MODULE_CODE}}-NNN | TS-{{MODULE_CODE}}-NNN | ✅ |

---

## 4. تتبع الشاشات (Screen → All) — {{N/N}}

| Screen | الوصف | FR | Flow | API | TS |
|---|---|---|---|---|---|
| SCR-{{MODULE_CODE}}-001 | {{…}} | FR-{{MODULE_CODE}}-NNN | FLOW-{{MODULE_CODE}}-NNN | API-{{MODULE_CODE}}-NNN | TS-{{MODULE_CODE}}-NNN |

---

## 5. تتبع API (API → All) — {{N/N}}

جميع API-{{MODULE_CODE}}-001..NNN مربوطة بـFR/BR/Flow/Screen/US/TS (§1–§4 والمصفوفة في `api-contracts.md §4`). **{{N/N}} REST + {{N/N}} M2M ({{100%}})**

> {{نقطة مُستحدَثة بعد الإصدار الأول: رقمها وسببها وأين تتبّعها}}

---

## 6. تتبع الجداول (Table → All) — {{N/N}}

| الجدول | الأعمدة | FR | BR | TS |
|---|---|---|---|---|
| `{{module_code}}_{{entities}}` | {{N}} | FR-{{MODULE_CODE}}-NNN | BR-{{MODULE_CODE}}-NNN | TS-{{MODULE_CODE}}-NNN |

---

## 7. تتبع آلة الحالات

| الآلة | القيم | BR | TS |
|---|---|---|---|
| `{{module_code}}_{{entities}}.status` ({{N}} حالات / {{N}} انتقالًا) | {{STATE_A, STATE_B, …}} | BR-{{MODULE_CODE}}-NNN | TS-{{MODULE_CODE}}-NNN..NNN |

---

## 8. إحصائيات التغطية الإجمالية

| البُعد | المجموع | المُغطى | النسبة |
|---|---|---|---|
| FR | {{N}} | {{N}} | {{100%}} |
| BR | {{N}} | {{N}} | {{100%}} |
| Flow | {{N}} | {{N}} | {{100%}} |
| Screen | {{N}} | {{N}} | {{100%}} |
| API REST | {{N}} | {{N}} | {{100%}} |
| API M2M | {{N}} | {{N}} | {{100%}} |
| US | {{N}} | {{N}} | {{100%}} |
| TS | {{N}} | {{N}} | {{100%}} |
| Table | {{N}} | {{N}} | {{100%}} |
| State Machine | {{N}} ({{N}} انتقالًا) | {{N}} | {{100%}} |
| Audit | {{N}} | {{N}} | {{100%}} |

---

## 9. ملاحظات

| # | الملاحظة | التصنيف |
|---|---|---|
| 1 | {{قرار مفتوح يمسّ التتبع · فجوة معلَنة · مدخل غير مقروء}} | {{OPEN | CLOSED — DEC-ID | فجوة مُعلَنة}} |

---

## 10. التنفيذ ⟵ المعرّف الهندسي — شريحة `SL-{{MODULE_CODE}}-NN`

> {{تاريخ الشريحة والتزامها — يُضاف قسم كهذا لكل شريحة تنفيذ، ولا يُحذف قسم سابق}}

| المعرّف | النوع | المكوّن | الأثر الهندسيّ الحاكم | المرجع |
|---|---|---|---|---|
| `CMP-{{MODULE_CODE}}-NNN` | `{{MIGRATION | MODEL | SERVICE | CONTRACT | CONTROLLER | SCREEN | API_CLIENT}}` | `{{مسار الملف في الكود}}` | {{ما يثبته هذا المكوّن مقابل العقد}} | `{{ENT-/API-/US-/SCR-…}}` |

### ما لم يُبنَ عمدًا، وسندُه

| البند | السبب | المعيارُ المتأثّر |
|---|---|---|
| {{العنصر الذي كان في النطاق ولم يُبنَ}} | {{القرار أو العقد الذي يمنعه أو يرحّله}} | {{بند DoD أو AC المتأثر}} |

### التعارضات المُستجدّة — تُرفع ولا تُحسم

| # | التعارض | المصدران | المبنيّ اليوم |
|---|---|---|---|
| `CFL-NN` | {{وصف التعارض}} | {{الوثيقة أ §n مقابل الوثيقة ب §m}} | {{ما بُني بانتظار الحسم — بالمسار الأكثر أمانًا}} |

---

## سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| 1.0 | {{DATE}} | الإصدار الأول — {{N}} أبعاد، {{100%}} تغطية | Draft |
