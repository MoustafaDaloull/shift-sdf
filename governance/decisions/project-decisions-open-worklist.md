---
document_type: Framework Template
framework: Shift SDF
file: governance/decisions/project-decisions-open-worklist.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/00-product/project-decisions-open-worklist.md
language: ar
generalization: reviewed
---

# قالب قائمة عمل القرارات المفتوحة — Open Decision Worklist

> **كيف يُستعمل:** يُنسخ إلى `docs/00-product/project-decisions-open-worklist.md`. كل صف فيه مسنود بسطر أو مرجع صريح في السجل أو في أحد المصادر الثانوية المذكورة في الترويسة.

## ترويسة الملف في المشروع

```yaml
---
document_type: Open Decision Worklist — Derived Read-Only Operational View
project_name: {{PROJECT_NAME}}
document_version: "0.1"
document_status: Baseline
language: ar
owner: {{OWNER}}
last_updated: {{YYYY-MM-DD}}
source_file: docs/00-product/project-decisions.md
source_version: "{{إصدار السجل}}"
secondary_sources:
  - PROJECT-BASELINE.md ({{الإصدار}})
  - docs/03-development/architecture.md ({{الإصدار}})
  - docs/99-quality/{{تقرير تدقيق}}.md
  - docs/00-product/project-decisions-index.md ({{الإصدار}})
decision_ref: {{معرّف الخطوة}}
---
```

---

# قائمة عمل القرارات المفتوحة — Open Decision Worklist

> **هذا الملف طبقة تشغيلية مشتقة للقراءة فقط (Derived, Read-Only)** — **ليس** مصدر الحقيقة.
>
> مصدر الحقيقة الوحيد هو `docs/00-product/project-decisions.md`. عند أي تعارض بين هذا الملف والسجل المرجعي، أو بين هذا الملف و`PROJECT-BASELINE.md` أو `architecture.md`: **يسود `project-decisions.md` أولًا**، ثم `PROJECT-BASELINE.md`، ثم `architecture.md`، حسب سلّم مصادر الحقيقة المعتمد في المشروع.
>
> **الغرض:** تجميع جميع القرارات `OPEN` / `مفتوح` / `مؤجَّل (DEFERRED)` / `مقترح (PROPOSED)` / غير المحسومة في مكان واحد، مصنّفة حسب **أثرها على الحجب الهندسي (Blocker Classification)**، ليستخدمها {{OWNER}} والفريق الهندسي كقائمة متابعة تشغيلية.
>
> **لا يجوز البناء على تصنيف الحجب هنا كقرار جديد.** كل تصنيف مشتق من دليل موثّق في المصدر المذكور بعمود "Source" — لم يُستنتج أي حجب بدون سند.
>
> لا يُستخدم هذا الملف لاتخاذ قرار أو إغلاق قرار. إغلاق أي بند يتم **فقط** بتحديث `project-decisions.md` من {{OWNER}}، ثم تُحدَّث هذه القائمة تبعًا لذلك (Manual Sync — لا مزامنة آلية).

---

## 0. تصنيفات الحجب المستخدمة (Blocker Classification Legend)

| التصنيف | المعنى |
|---|---|
| `GLOBAL ENGINEERING` | يحجب كل العمل الهندسي في المشروع |
| `MODULE-SPECIFIC` | يحجب موديولًا محددًا فقط |
| `FEATURE-SPECIFIC` | يحجب ميزة محددة داخل موديول |
| `IMPLEMENTATION-ONLY` | يحجب التنفيذ فقط، لا التحليل أو التصميم |
| `PRE-RELEASE` | يجب حسمه قبل الإطلاق التجاري، لا يحجب التطوير |
| `NON-BLOCKING` | معلوماتي أو مؤجَّل أو محدود الأثر |
| `UNKNOWN — REVIEW REQUIRED` | دليل غير كافٍ للتصنيف |

**ملاحظة منهجية:** حكمُ جاهزيةٍ عام صادر عن تقرير تدقيق (مثل `NOT READY` لأسباب حوكمية) **ليس «قرارًا مفتوحًا»** ولا يُدرج هنا؛ يُتابَع في تقريره.

---

## 1. الجدول الرئيسي — كل البنود

| Decision | Status | Domain | Affected Modules | Blocks | Required Before | Approver/Owner | Source |
|---|---|---|---|---|---|---|---|
| {{OD-NNN / DEC-...}} | {{مفتوح — بانتظار ...}} | {{النطاق}} | {{MOD-NN}} | {{`MODULE-SPECIFIC`}} | {{ما الذي لا يبدأ قبله}} | {{{{OWNER}} / جهة خارجية}} | {{project-decisions.md:n–n · تقرير}} |

---

## 2. القسم الأول — MODULE-SPECIFIC (يحجب موديولًا محددًا)

### {{DEC-... — العنوان}}
- **الحالة:** {{مفتوح — بانتظار ...}}
- **الموديولات المتأثرة:** {{MOD-NN (الاسم)}}
- **الحجب:** `MODULE-SPECIFIC` — {{ما الذي يمنعه تحديدًا، مع مرجع الدليل}}
- **مطلوب قبل:** {{المرحلة أو المخرج}}
- **المصدر:** {{project-decisions.md §X (سطر n–n)؛ المصادر الثانوية}}

## 3. القسم الثاني — IMPLEMENTATION-ONLY (يحجب التنفيذ فقط)

| Decision | Status | ما الذي يحجبه | Source |
|---|---|---|---|
| {{...}} | {{...}} | {{...}} | {{...}} |

## 4. القسم الثالث — PRE-RELEASE (قبل الإطلاق التجاري، لا يحجب التطوير)

| Decision | Status | ما الذي يلزم قبل الإطلاق | Source |
|---|---|---|---|
| {{...}} | {{...}} | {{...}} | {{...}} |

## 5. القسم الرابع — FEATURE-SPECIFIC (يحجب ميزة محددة داخل موديول)

| Decision | Status | الميزة المحجوبة | Source |
|---|---|---|---|
| {{...}} | {{...}} | {{...}} | {{...}} |

## 6. القسم الخامس — NON-BLOCKING (معلوماتي / مؤجَّل / محدود الأثر)

| Decision | Status | ملاحظة | Source |
|---|---|---|---|
| {{...}} | {{...}} | {{...}} | {{...}} |

## 7. القسم السادس — UNKNOWN — REVIEW REQUIRED

| Decision | Status | سبب تعذّر التصنيف | Source |
|---|---|---|---|
| {{...}} | {{...}} | {{...}} | {{...}} |

---

## 8. ملاحظات المطابقة والتصحيح (Reconciliation Notes)

هذا القسم يوثّق تعارضات أو معلومات غير دقيقة اكتُشفت أثناء بناء هذه القائمة عند مطابقة موجز الطلب الأصلي بالمصدر المرجعي وملفات الأدلة. **لم يُعدَّل أي ملف مصدري بناءً على هذه الملاحظات** — التصحيح هنا مقصور على محتوى هذا الملف المشتق فقط.

1. {{الملاحظة — مع السطر والمرجع}}

---

## 9. قواعد الصيانة

1. هذا الملف **يُحدَّث يدويًا فقط** بعد أي تحديث لإصدار `project-decisions.md` يُغلق أو يفتح أو يُعدِّل أحد البنود المدرجة هنا.
2. لا تُضف بندًا هنا دون رقم سطر أو مرجع صريح في `project-decisions.md` أو `PROJECT-BASELINE.md` أو أحد تقارير `docs/99-quality/` المذكورة في `secondary_sources` أعلاه.
3. لا يُستنتج تصنيف حجب (`Blocks`) من اسم الموديول أو من طبيعة القرار وحدها — يجب وجود جملة صريحة في المصدر تربط القرار بنطاق حجبه.
4. عند إغلاق أي بند في `project-decisions.md`، يُنقَل من جدول §1 والقسم المخصص له إلى سجل تاريخي مختصر في §10 أدناه، لا يُحذف بصمت.
5. أي تعارض جديد بين هذا الملف والمصدر المرجعي يُسجَّل في §8 (ملاحظات المطابقة)، ولا يُصحَّح المصدر المرجعي من هذا الملف.

---

## 10. سجل الإصدارات والبنود المُغلقة

| الإصدار | التاريخ | التغيير | الحالة |
|---|---|---|---|
| {{0.1}} | {{YYYY-MM-DD}} | {{إنشاء أولي — n صفًا مصنّفة (توزيعها على التصنيفات)؛ ما صُحِّح مقابل الموجز الأولي}} | {{معتمد (مشتق)}} |
