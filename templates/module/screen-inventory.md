---
document_type: Framework Template
framework: Shift SDF
file: templates/module/screen-inventory.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/01-modules/auctions/screen-inventory.md
language: ar
generalization: reviewed
---

# قالب — `screen-inventory.md` — حصر الشاشات

> **frontmatter الوثيقة عند الاستخدام:**

```yaml
---
document_type: Screen Inventory
module_id: {{MODULE_ID}}
module_code: {{MODULE_CODE}}
module_name_ar: {{MODULE_NAME}}
phase: {{PHASE}}
status: {{مسودة | جاهز للمراجعة | معتمد}}
last_updated: {{DATE}}
version: "{{X.Y}}"
---
```

## قواعد هذه الوثيقة

- المعرّف: `SCR-{{MODULE_CODE}}-NNN` — متسلسل · ثابت · لا يُعاد ترقيمه. ولكل صفّ في الحصر ملف مواصفة `screens/SCR-XXX-NNN.md`.
- كل شاشة مرتبطة بهدف مستخدم أو تدفق أو حالة نظام؛ ولا شاشة مكررة لوظيفة مملوكة لموديول آخر (تُدرج في §3 إحالةً لا حصرًا).
- نوع الشاشة من مفردات ثابتة: `List` · `Details` · `Create / Wizard` · `Edit` · `Details / Action` · `Details / Status` · `Dashboard` · `Summary` (أو مفردات نظام التصميم المعتمد).
- «حالة التوثيق» في تفاصيل كل شاشة تطابق حالة ملفها في `screens/` — عدٌّ قديم أو حالة قديمة ملاحظة في البوابة.
- الأولوية والمرحلة في الحصر هي المرجع لملف الشاشة، لا العكس.
- تُراجَع بـ`screen-quality-gate.md` مع `permission-matrix.md` وملفات `screens/`.

---

# حصر الشاشات — {{MODULE_ID}} ({{MODULE_CODE}})
# {{MODULE_NAME}}

> **تحديث {{DATE}} (`{{DEC-ID}}`):** {{ملخص آخر تعديل جوهري — يُحذف إن لم يوجد}}

---

## ملخص الشاشات

| المعرِّف | اسم الشاشة | الأدوار | النوع | الأولوية | المرحلة |
|---|---|---|---|---|---|
| SCR-{{MODULE_CODE}}-001 | {{اسم الشاشة}} | {{ROLE_A, ROLE_B}} | {{Create / Wizard}} | {{Must}} | {{PHASE}} |

---

## تفاصيل الشاشات

---

### SCR-{{MODULE_CODE}}-001 — {{اسم الشاشة}}

| الحقل | القيمة |
|---|---|
| معرِّف الشاشة | SCR-{{MODULE_CODE}}-001 |
| اسم الشاشة | {{اسم الشاشة}} |
| الغرض | {{ما تمكّن المستخدم من فعله}} |
| الأدوار المستهدفة | {{ROLE_A}} |
| نوع الشاشة | {{Create / Wizard}} |
| الأولوية | {{Must}} |
| المرحلة | {{PHASE}} |
| التدفقات ذات الصلة | FLOW-{{MODULE_CODE}}-NNN |
| المتطلبات ذات الصلة | FR-{{MODULE_CODE}}-NNN |
| قواعد العمل الحساسة | BR-{{MODULE_CODE}}-NNN |
| حالة التوثيق | {{لم تبدأ | مسودة | معتمد}} |

**الأقسام:**
- {{القسم الأول وما يعرضه أو يدخله — بمرجع المصدر إن كان من موديول آخر}}
- {{…}}

**حالات الشاشة:** {{Initial، Loading، Empty، Validation Error، Success، Permission Denied — حسب الانطباق}}

**ملاحظة نطاقية:** {{ما يُخفى أو يُستثنى وسببه — يُحذف إن لم يوجد}}

---

### SCR-{{MODULE_CODE}}-002 — {{اسم الشاشة}}

| الحقل | القيمة |
|---|---|
| معرِّف الشاشة | SCR-{{MODULE_CODE}}-002 |
| اسم الشاشة | {{…}} |
| الغرض | {{…}} |
| الأدوار المستهدفة | {{…}} |
| نوع الشاشة | {{…}} |
| الأولوية | {{…}} |
| المرحلة | {{…}} |
| التدفقات ذات الصلة | {{…}} |
| المتطلبات ذات الصلة | {{…}} |
| قواعد العمل الحساسة | {{…}} |
| حالة التوثيق | {{…}} |

**الأقسام:**
- {{…}}

**حالات الشاشة:** {{…}}

---

## قائمة الشاشات خارج النطاق (مملوكة لموديولات أخرى)

| الشاشة | الموديول المالك | ملاحظة |
|---|---|---|
| {{بوابة الدفع}} | {{MOD-NN}} | {{هذا الموديول يُوجَّه إليها فقط / يستقبل نتيجتها}} |

---

## مصفوفة الشاشات والتدفقات

| الشاشة | التدفقات المرتبطة |
|---|---|
| SCR-{{MODULE_CODE}}-001 | FLOW-{{MODULE_CODE}}-NNN |

---

## سجل الإصدارات

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| 1.0 | {{DATE}} | إنشاء `screen-inventory.md` لـ{{MODULE_ID}} | مسودة |

---

```text
STATUS = {{APPROVED | NEEDS_REVISION | BLOCKED | CONDITIONAL_REVIEW}}
```
