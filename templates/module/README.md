---
document_type: Framework Template
framework: Shift SDF
file: templates/module/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/01-modules/ (بنية الحزمة المشتركة بين الموديولات)
language: ar
generalization: reviewed
---

# حزمة توثيق الموديول — دليل القوالب

> هذا المجلد يحمل **قوالب فارغة** لحزمة توثيق الموديول الواحد: تسع وثائق لمرحلة التحليل (Phase 0) وخمس وثائق للحزمة الهندسية، ومجلد `screens/` بمواصفة لكل شاشة. القالب يحدد **البنية والمعرّفات والمفردات وقواعد الوثيقة**، ولا يحمل محتوى مشروع. تُنسخ الحزمة كاملةً إلى مجلد الموديول في المشروع وتُملأ بالترتيب المبيَّن في §3.

---

## 1. قاعدة التسمية — ثلاثة أسماء لموديول واحد

لكل موديول **ثلاثة أسماء** تُشتق من بعضها ولا تُخترع، ويحكمها سجل الموديولات (`module-registry.md`) وخريطة المعرّفات (`identifier-alias-map.md`) في المشروع:

| العنصر | الصيغة | مثال (`ORD` — الطلبات) | أين يُستعمل |
|---|---|---|---|
| معرّف الموديول | `MOD-NN` | `MOD-NN` | سجل الموديولات · frontmatter كل وثيقة |
| كود الموديول | **ثلاثة أحرف لاتينية كبيرة** | `ORD` | بادئة كل معرّف في الحزمة (`FR-ORD-NNN`) · **بادئة الجداول** (`ord_orders`) · **قطاع مسار API** (`/api/v1/ord/...`) |
| مجلد التوثيق | `kebab-case` | `docs/01-modules/orders/` | حزمة التوثيق |
| مجلد الكود | `PascalCase` — **الاسم كامل لا مختصر** | `backend/app/Modules/Orders/` | كود الموديول |
| الاسم الرسمي | عربي + إنجليزي | الطلبات / Orders | `module_name_ar` · `module_name_en` |

**قاعدتان حاكمتان:**

1. **الكود هو الكود المسجَّل، لا اختصارٌ يُشتق من الاسم.** إذا سجّلت خريطة المعرّفات كودًا مغايرًا لما توحي به الأحرف الأولى من الاسم فالمسجَّل هو الصحيح.
2. **المجلدان يُشتقان من الاسم لا من الكود:** `docs/01-modules/<اسم-بالواصلات>/` ⟵ `backend/app/Modules/<الاسمPascal>/`. أما الكود فيظهر في الجدول والمسار والمعرّفات فقط.

---

## 2. الوثائق الأربع عشرة ومجلد الشاشات

| # | الوثيقة | المرحلة | بادئة المعرّفات التي تُسَكّ فيها | بوابة الجودة التي تراجعها |
|---|---|---|---|---|
| 1 | `requirements.md` | Phase 0 | `FR-{{MODULE_CODE}}-NNN` · `NFR-{{MODULE_CODE}}-NNN` | `requirements-quality-gate.md` (أو نسخة مرحلة الواجهة) |
| 2 | `business-rules.md` | Phase 0 | `BR-{{MODULE_CODE}}-NNN` | `business-rules-quality-gate.md` |
| 3 | `user-flows.md` | Phase 0 | `FLOW-{{MODULE_CODE}}-NNN` | `user-flows-quality-gate.md` (أو نسخة مرحلة الواجهة) |
| 4 | `screen-inventory.md` | Phase 0 | `SCR-{{MODULE_CODE}}-NNN` (الحصر) | `screen-quality-gate.md` (أو نسخة مرحلة الواجهة) |
| 5 | `permission-matrix.md` | Phase 0 | `PM-{{MODULE_CODE}}-NNN` | `screen-quality-gate.md` (ضمن حزمة الشاشات) |
| 6 | `screens/SCR-XXX-NNN.md` | Phase 0 | `AC-SCR-{{MODULE_CODE}}-NNN-NNN` | `screen-quality-gate.md` — لكل ملف شاشة على حدة |
| 7 | `module-readiness-review.md` | إغلاق Phase 0 | `OBS-{{MODULE_CODE}}-NNN` | تجميع نتائج بوابات Phase 0 الست (Module Final Audit — المراجعات السبع) |
| 8 | `engineering-input-analysis.md` | الهندسة (أولًا) | `SEC-{{MODULE_CODE}}-NNN` (قواعد الأمن المستخلصة) | `engineering-input-quality-gate.md` |
| 9 | `data-model.md` | الهندسة | `ENT-{{MODULE_CODE}}-NNN` · `EVT-{{MODULE_CODE}}-NNN` · `CK-{{MODULE_CODE}}-XXNN` | `data-model-quality-gate.md` |
| 10 | `api-contracts.md` | الهندسة | `API-{{MODULE_CODE}}-NNN` · `ERR-{{MODULE_CODE}}-<KIND>-NNN` | `api-contract-quality-gate.md` |
| 11 | `user-stories.md` | الهندسة | `US-{{MODULE_CODE}}-NNN` · `AC-NNN-NN` | `user-stories-quality-gate.md` |
| 12 | `test-scenarios.md` | الهندسة | `TS-{{MODULE_CODE}}-NNN` | `test-scenarios-quality-gate.md` |
| 13 | `traceability-matrix.md` | الهندسة (أخيرًا) | — (لا تسكّ معرّفًا؛ تربط ما سُكّ) | تُراجَع ضمن `development-readiness-quality-gate.md` |
| 14 | `module-development-readiness-review.md` | إغلاق الهندسة | `DR-{{MODULE_CODE}}-NNN` | `development-readiness-quality-gate.md` |

---

## 3. ترتيب الإنتاج — ولا يُقفَز فوق خطوة

```text
Phase 0
  requirements.md
    ⟶ business-rules.md
      ⟶ user-flows.md
        ⟶ screen-inventory.md + permission-matrix.md
          ⟶ screens/SCR-XXX-NNN.md  (ملف لكل صفّ في الحصر)
            ⟶ module-readiness-review.md         (المراجعات السبع ⟶ STATUS)
                 ⟶ اعتماد مالك المنتج للحزمة

الحزمة الهندسية  (لا تبدأ قبل اعتماد Phase 0)
  engineering-input-analysis.md
    ⟶ data-model.md
      ⟶ api-contracts.md
        ⟶ user-stories.md
          ⟶ test-scenarios.md
            ⟶ traceability-matrix.md
              ⟶ module-development-readiness-review.md  (المراجعات السبع + Mini-Audit ⟶ STATUS)
                   ⟶ اعتماد مالك المنتج للحزمة الهندسية
```

- كل وثيقة تمرّ ببوابتها **قبل** أن تبدأ الوثيقة التالية التي تشتقّ منها.
- بوابة الجودة تُجرى **مراجعةً ذاتيةً تلقائيةً** قبل عرض الوثيقة على مالك المنتج، وتقريرها جزء من التسليم (انظر `templates/quality-gates/README.md`).
- مالك المنتج يعتمد **بعد** تقرير البوابة لا قبله، واعتماده يُسجَّل في frontmatter الوثيقة وفي سجل القرارات.

---

## 4. قواعد مشتركة بين وثائق الحزمة كلها

1. **المعرّف ثابت لا يُعاد ترقيمه.** المعرّف الذي سُكّ يبقى ولو حُذف محتواه؛ الحذف يُسجَّل في سجل الإصدارات ويُترك الرقم شاغرًا.
2. **لا اختراع.** الوثيقة تُنزِّل ما هو معتمد (BRD · سجل القرارات · القواعد العالمية · إجابات مالك المنتج). ما لا مصدر له يُسجَّل `OPEN` ويُرفع، ولا يُملأ بالاجتهاد.
3. **المال والصلاحيات والملكية والخصوصية والقانون** لا تُحسم داخل وثيقة موديول — تُرفع بوابةَ قرار بشري.
4. **الوظيفة المشتركة لها مالك واحد.** الموديول المستهلك يُشير إلى المالك ولا يعيد تعريف منطقه (OTP · الدفع · الإشعارات · التدقيق · الوسائط · البحث · الإعدادات).
5. **سجل الإصدارات إلزامي** في كل وثيقة: (الإصدار | التاريخ | التغيير | الحالة)، والتاريخ `YYYY-MM-DD`.
6. **مفردات الحالة** في frontmatter وثائق Phase 0: `مسودة` · `جاهز للمراجعة` · `معتمد`؛ وفي الوثائق الهندسية: `Draft` · `Approved`. وحكم البوابة: `STATUS = APPROVED` / `BLOCKED` / `NEEDS_REVISION` / `CONDITIONAL_REVIEW`.
7. **الأرقام الإحصائية** في الملخصات (عدد FR · BR · شاشات …) تُحسب من الوثيقة نفسها وتُطابَق عند كل تعديل؛ عدٌّ قديم في ملخص = ملاحظة في البوابة.
8. **بعد اعتماد الحزمة تصير وثائق Phase 0 محميّة**: لا تُعدَّل من مرحلة التنفيذ إلا بـChange Request معتمد أو تصحيح خطأ واقعي بإذن مالك المنتج.

---

## 5. كيف تُستعمل القوالب

1. انسخ المجلد كاملًا إلى `docs/01-modules/<module-slug>/`.
2. استبدل العناصر النائبة: `{{PROJECT_NAME}}` · `{{MODULE_CODE}}` · `{{MODULE_NAME}}` · `{{MODULE_NAME_EN}}` · `{{MODULE_ID}}` · `{{OWNER}}` · `{{PHASE}}` · `{{DATE}}`.
3. أزل كتلة «قواعد هذه الوثيقة» إن شئت عند الاعتماد النهائي — أو أبقِها؛ وجودها لا يخلّ بالبوابة.
4. الصف النائب في كل جدول يُستبدل بصفوف حقيقية ولا يُترك.
5. أعِد تسمية `screens/SCR-XXX-NNN.md` لكل شاشة في الحصر بمعرّفها الفعلي.
