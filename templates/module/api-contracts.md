---
document_type: Framework Template
framework: Shift SDF
file: templates/module/api-contracts.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/01-modules/auctions/api-contracts.md
language: ar
generalization: reviewed
---

# قالب — `api-contracts.md` — عقود API

> **frontmatter الوثيقة عند الاستخدام:**

```yaml
---
module_id: {{MODULE_ID}}
module_code: {{MODULE_CODE}}
module_name_ar: {{MODULE_NAME}}
document_type: api-contracts
document_version: "{{X.Y}}"
document_status: {{Draft | Approved}}
wave: "{{موجة التوثيق الهندسي}}"
last_updated: {{DATE}}
author: {{الدور الكاتب}}
source_artifact: engineering-input-analysis.md v{{X.Y}}, data-model.md v{{X.Y}}
governing_standards:
  - {{معيار تصميم API}}
  - {{معيار عقد الخطأ}}
  - {{معيار التفويض}}
  - {{معيار المصادقة}}
---
```

## قواعد هذه الوثيقة

- المعرّف: `API-{{MODULE_CODE}}-NNN` — ثابت لا يُعاد ترقيمه؛ ونقطة تُستحدث لاحقًا تأخذ الرقم التالي ويُسجَّل سببها.
- المسار: `/api/v1/{{module_code}}/...` للعامة والمستخدم، و`/api/v1/{{module_code}}/admin/...` للإدارة. **قطاع المسار هو كود الموديول**.
- **الفعل (الإجراء) تحت `/actions/<verb>`** — لا مسار بصيغة فعل خارجه.
- §1 فهرس بالمجموعات (الدور) وعمود `FR` لكل نقطة؛ §1B **العقد التفصيلي** لكل نقطة: الدور والصلاحية · الجسم (كل حقل بنوعه وإلزاميته وقيوده) · الأهلية والتحقق بأكواد الأخطاء · الاستجابة · النجاح (الحالة الناتجة · الأحداث · التدقيق).
- واجهات M2M (العقود العابرة الصادرة والواردة) تُجدوَل بمعرّف `API-{{MODULE_CODE}}-INT-NNN` أو `IN-/OUT-` بحسب اصطلاح المشروع، وتذكر المستهلك.
- الأخطاء: `ERR-{{MODULE_CODE}}-<KIND>-NNN` حيث `KIND` ∈ `VAL` (تحقق 422) · `BIZ` (قاعدة عمل 422/409) · `AUZ` (تفويض 403/404) · `NF` (غير موجود 404) — وكل كود في كتالوج §3 مرة واحدة؛ **لا كود جديد لسبب فرعي** — يُحمل السبب في `error.details`.
- التفويض **صفٌّ صريح في `permission-matrix.md`** يُسمّى في العقد؛ ولا يُعاد حقل حساس لمن لا يملك رؤيته (`SEC-{{MODULE_CODE}}-NNN`).
- الاستجابة الموحّدة وأشكال الترقيم والترتيب والفلترة بمعيار API للمشروع — لا شكل خاص بالموديول.
- عقد نقطة مُستحدَث **يُفتح شريحةً بشريحة** مع التنفيذ إن لم يكن مفتوحًا من البداية، ويُنصّ على المفتوح.
- تُراجَع بـ`api-contract-quality-gate.md` قبل بدء `user-stories.md`.

---

# API Contracts — {{MODULE_ID}} ({{MODULE_CODE}})
# {{MODULE_NAME}}

> {{مدخل غير مقروء آليًا — إن وُجد: مراجعة يدوية مطلوبة}}

---

## 1. نقاط النهاية ({{N}} REST + {{N}} M2M)

### 1.1 {{المجموعة الأولى}} ({{ROLE_A}})

| # | Method | Path | FR |
|---|---|---|---|
| API-{{MODULE_CODE}}-001 | POST | /api/v1/{{module_code}}/{{resources}} | FR-{{MODULE_CODE}}-NNN |
| API-{{MODULE_CODE}}-002 | GET | /api/v1/{{module_code}}/{{resources}}/{id} | FR-{{MODULE_CODE}}-NNN |
| API-{{MODULE_CODE}}-003 | POST | /api/v1/{{module_code}}/{{resources}}/{id}/actions/{{verb}} | FR-{{MODULE_CODE}}-NNN |

### 1.2 {{المجموعة الإدارية}} ({{ROLE_ADMIN}})

| # | Method | Path | FR |
|---|---|---|---|
| API-{{MODULE_CODE}}-NNN | GET | /api/v1/{{module_code}}/admin/{{resources}} | FR-{{MODULE_CODE}}-NNN |
| API-{{MODULE_CODE}}-NNN | POST | /api/v1/{{module_code}}/admin/{{resources}}/{id}/actions/{{verb}} | FR-{{MODULE_CODE}}-NNN |

### 1.3 واجهات M2M ({{N}})

| المعرّف | النوع | الغرض |
|---|---|---|
| API-{{MODULE_CODE}}-INT-001 | {{صادر (OUT) | وارد (IN)}} | {{العقد المستهلَك أو المقدَّم — والمستهلك/المالك}} |

---

## 1B. العقود التفصيلية

### 1B.1 — `API-{{MODULE_CODE}}-001` · POST `/api/v1/{{module_code}}/{{resources}}`

- **الدور:** {{ROLE_A}} حصرًا (`PM-{{MODULE_CODE}}-NNN`). غيرُه يُرفض بـ`ERR-{{MODULE_CODE}}-AUZ-NNN` 403.
- **الجسم:** `{{field_a}}` (إلزامي · {{النوع والقيد}}) · `{{field_b}}` (اختياري · {{…}}) · `{{amount}}` ({{> 0 · منزلتان}})
- **الأهلية (`BR-{{MODULE_CODE}}-NNN` — `ERR-{{MODULE_CODE}}-BIZ-NNN` 422):** {{الشروط بترتيب فحصها}}
- **سبب الرفض:** `error.details` يحمل عنصرًا واحدًا `{ "field": "reason", "code": "ERR-{{MODULE_CODE}}-BIZ-NNN", "message": "<reason>" }`:

  | `reason` | البند |
  |---|---|
  | `{{not_owner}}` | {{البند — وما لا يُميَّز عمدًا لأسباب الخصوصية}} |

- **النجاح:** 201 — السجل `{{STATE_A}}`، حدث `EVT-{{MODULE_CODE}}-NNN`، وتدقيق `{{entity.created}}` (BR-{{MODULE_CODE}}-NNN).

### 1B.2 — `API-{{MODULE_CODE}}-002` · GET `/api/v1/{{module_code}}/{{resources}}/{id}`

- **الدور:** {{…}} — سجل لا يملكه الطالب يُرجع **404** لا 403 (anti-leak).
- **الاستجابة:**

  | الحقل | النوع | المعنى |
  |---|---|---|
  | `id` | {{integer}} | المعرّف |
  | `status` | {{string}} | الحالة |
  | `{{sensitive_field}}` | {{…}} | {{يظهر لـ… فقط — SEC-{{MODULE_CODE}}-NNN}} |

---

## 2. الأمن ({{N}} قواعد — SEC-{{MODULE_CODE}}-001..NNN)

| القاعدة | التطبيق |
|---|---|
| SEC-{{MODULE_CODE}}-001 ({{موجز}}) | {{أي النقاط تطبقها وكيف — مثال: API-… لا تُرجع الحقل لأي مستخدم}} |

---

## 3. كتالوج الأخطاء ({{N}} كودًا)

| الكود | HTTP | الوصف |
|---|---|---|
| ERR-{{MODULE_CODE}}-VAL-001 | 422 | {{بيانات غير صالحة}} |
| ERR-{{MODULE_CODE}}-BIZ-001 | 422 | {{إخلال بقاعدة عمل}} |
| ERR-{{MODULE_CODE}}-AUZ-001 | 403 | {{غير مخوَّل}} |

---

## 4. مصفوفة التتبع (API → مصدر)

| API | FR | BR | Flow | Screen |
|---|---|---|---|---|
| API-{{MODULE_CODE}}-001..NNN | FR-{{MODULE_CODE}}-NNN | BR-{{MODULE_CODE}}-NNN | FLOW-{{MODULE_CODE}}-NNN | SCR-{{MODULE_CODE}}-NNN |

---

## سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| 1.0 | {{DATE}} | الإصدار الأول — {{N}} REST + {{N}} M2M · {{N}} قواعد أمن · {{N}} كود خطأ | Draft |
