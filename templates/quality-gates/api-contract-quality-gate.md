---
document_type: Framework Template
framework: Shift SDF
file: templates/quality-gates/api-contract-quality-gate.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/99-quality/api-contract-quality-gate.md
language: ar
generalization: reviewed
---

# بوابة جودة عقود API — API Contracts Quality Gate

**الإصدار:** 1.0  
**المسار القياسي:** `docs/99-quality/api-contract-quality-gate.md`  
**الحالة:** مرجع إلزامي  
**النطاق:** جميع موديولات {{PROJECT_NAME}} ما لم يعتمد مالك المنتج استثناءً صريحًا.

---

## 1. الغرض

تضمن هذه البوابة أن `api-contracts.md` يعرّف واجهات API واضحة وآمنة وقابلة للتنفيذ والاختبار ومتسقة مع الصلاحيات والبيانات والقواعد والشاشات، دون تكرار خدمات مملوكة لموديولات أخرى.

---

## 2. متى تُنفذ؟

- بعد إعداد أو تعديل `api-contracts.md`.
- قبل تنفيذ Backend أو ربط Frontend أو QA Contract Testing.
- عند تغيير Authorization أو البيانات أو الحالات أو التكاملات.

---

## 3. المراجع والمدخلات الإلزامية

- `requirements.md`
- `business-rules.md`
- `permission-matrix.md`
- `data-model.md`
- `screens/`
- `user-flows.md`
- `module-registry.md`
- `قرارات ووثائق التكامل والمعايير الهندسية المعتمدة`

لا تُنشئ افتراضًا بدل مرجع مفقود. سجّل المرجع المفقود أو القرار الناقص كـ `OPEN`، واعتبره عائقًا إذا كان يؤثر في المال أو الصلاحيات أو الملكية أو الحالة أو الخصوصية أو الالتزام القانوني.

---

## 4. بروتوكول المراجعة الإلزامي

1. راجع كل Endpoint ثم راجع العقود كمجموعة.
2. اربط كل Endpoint بحاجته الوظيفية أو Screen أو Flow.
3. اختبر النجاح والفشل والتكرار والتزامن والبيانات غير المسموحة.
4. تحقق من Authorization على الخادم لا على الواجهة فقط.
5. أصدر التقرير ثم أصلح Critical وHigh وأعد المراجعة.

---

## 5. قائمة التحقق

### الهوية والغرض

- [ ] المسار والـ Method والمعرف والغرض محددون.
- [ ] المتطلبات والشاشات والتدفقات المرتبطة مدرجة.
- [ ] لا توجد Endpoints مكررة أو غير متسقة في التسمية.
- [ ] العقد يشير إلى موديول المالك عندما يستهلك خدمة مشتركة.

### Authentication وAuthorization

- [ ] نوع Authentication واضح.
- [ ] Permission أو Role أو Policy المطلوبة محددة.
- [ ] التفويض يتحقق من Ownership وScope عند الحاجة.
- [ ] الحقول الحساسة لا تعاد أو تقبل بلا صلاحية.
- [ ] Rate Limiting وAudit Log وIdempotency محددة للعمليات الحساسة عند الحاجة.

### Request وResponse

- [ ] كل path/query/body parameter موثق بالنوع والإلزامية والوصف.
- [ ] Rules وEnums وقيود الطلب متسقة مع Data Model وBusiness Rules.
- [ ] أمثلة Request وResponse صحيحة وقابلة للاستخدام.
- [ ] Pagination وFiltering وSorting وSearch موثقة عند الحاجة.
- [ ] الوقت والتاريخ والعملات والوحدات والحقول المشتقة محددة بدقة.

### الأخطاء والحالات

- [ ] أكواد النجاح والفشل موحدة.
- [ ] Validation وPermission Denied وNot Found وConflict وInvalid State مغطاة.
- [ ] Timeout وRetry وفشل التكامل موثقة عند الحاجة.
- [ ] لا تكشف الأخطاء بيانات حساسة أو تفاصيل تقنية.
- [ ] تكرار الطلب والفشل الجزئي وتغيير الحالة المتزامن محددة.

### الاتساق والتشغيل

- [ ] كل Endpoint يدعم Flow أو Screen أو عملية موثقة.
- [ ] تغير الحالة والمال والخصوصية يتبع قواعد العمل.
- [ ] Versioning وCompatibility موثقة عند الحاجة.
- [ ] Events أو Webhooks أو Async Jobs تحدد مصدر الحدث ووجهته وسلوك الفشل.

---

## 6. أسباب الرفض أو الإيقاف

- عملية حساسة بلا Authorization واضح.
- Request/Response يخالف Data Model أو Business Rule.
- غياب Error Contract لفشل أساسي.
- تغيير حالة بلا تحقق من الحالة الحالية.
- كشف بيانات حساسة أو قبول حقول غير آمنة.
- Endpoint بلا غرض أو يكرر API مملوكة لموديول آخر.

---

## 7. تصنيف الملاحظات

| المستوى | المعنى | أثره على الاعتماد |
|---|---|---|
| Critical | خطأ في النطاق أو المال أو الأمان أو الصلاحيات أو القانون أو حالة السجل | يمنع الاعتماد |
| High | نقص أو تعارض قد يسبب تنفيذًا خاطئًا أو إعادة عمل كبيرة | يمنع الاعتماد |
| Medium | فجوة مهمة تحتاج إصلاحًا أو موافقة صريحة | لا يعتمد تلقائيًا |
| Low | تحسين محدود في الوضوح أو الصياغة أو التنظيم | يمكن تأجيله |

---

## 8. قالب تقرير المراجعة

```markdown
# Quality Review — [MODULE CODE]

**الملف المراجع:** [المسار]  
**المراجع المستخدمة:** [قائمة]  
**حالة المراجعة:** PASS / CONDITIONAL PASS / FAIL

## ملخص الملاحظات
| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

## قابلية التتبع
| Endpoint | Method | Requirement / Flow / Screen | Permission | Data Entity | Result |
|---|---|---|---|---|---|

## Findings

### QG-[MODULE]-001
- **Severity:** Critical / High / Medium / Low
- **العنصر المتأثر:** [المعرف أو القسم]
- **الوصف:** [المشكلة بدقة]
- **الأثر:** [الأثر التشغيلي أو الفني أو القانوني]
- **التوصية:** [الإجراء المطلوب]
- **المرجع:** [Requirement / Rule / Flow / Decision / File]
- **الحالة:** Open / Resolved / Accepted Risk
```

---

## 9. معايير الاعتماد النهائي

- عدد `Critical = 0` و`High = 0`.
- كل Endpoint له غرض وسياق وصلاحية واضحة.
- Request وResponse وErrors قابلة للتنفيذ والاختبار.
- لا توجد تعارضات مع Data Model أو Screen Specs أو Rules.

لا تعتبر الوثيقة مكتملة أو جاهزة للمخرج التالي إلا بعد إعادة المراجعة عقب الإصلاح.

استخدم النتيجة النهائية فقط عند تحقق الشروط:

```text
STATUS = APPROVED
```

وفي غير ذلك استخدم الحالة المناسبة:

```text
STATUS = BLOCKED
STATUS = NEEDS_REVISION
STATUS = CONDITIONAL_REVIEW
```
