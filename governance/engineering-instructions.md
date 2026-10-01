---
document_type: Framework Instructions
framework: Shift SDF
file: governance/engineering-instructions.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/CLAUDE-ENGINEERING.md
language: ar
generalization: reviewed
---

# {{PROJECT_NAME}} — إطار المرحلة الهندسية

**اسم الملف:** `governance/engineering-instructions.md`
**الإصدار:** 0.1.0
**النطاق:** المرحلة الهندسية — Data Model، API Contracts، User Stories، Test Scenarios
**الحالة:** تعليمات تشغيل المرحلة الهندسية — تُفعَّل عند إنتاج أو تعديل وثيقة هندسية
**لغة العمل:** العربية هي اللغة الرئيسية. تستخدم الإنجليزية للمعرّفات وأسماء الملفات والمصطلحات التقنية عند الحاجة.

---

## 0. موجّه المراحل

يحتوي الإطار **ثلاثة** ملفات تعليمات، كلٌّ يحكم نوع مخرجه. **الملف المُحمَّل تلقائيًا في كل جلسة يجب أن يحمل قواعد المرحلة النشطة لا قواعد مرحلة منتهية.**

| الملف | المرحلة | متى يُفعَّل |
|---|---|---|
| `governance/execution-instructions.md` | **مرحلة التنفيذ — الكود** | عندما تكتب أو تعدّل كودًا أو اختبارًا أو بنية تحتية أو سكربتًا. وهو الملف الحاكم المُحمَّل تلقائيًا متى بدأت مرحلة التنفيذ. |
| `governance/engineering-instructions.md` (هذا الملف) | **المرحلة الهندسية — التوثيق** | عند إنتاج أو تعديل وثيقة هندسية: `data-model` · `api-contracts` · `user-stories` · `test-scenarios` · `traceability-matrix` · المعايير · البنية السحابية. وبعد اكتمال حزم الموديولات كلها يبقى حاكمًا لأي مخرج هندسي توثيقي لاحق: تعديل حزمة قائمة، أو حزمة موديول جديد بـChange Request. |
| `governance/phase0-instructions.md` | **Phase 0 — التحليل ومواصفات واجهات المستخدم** | عند إنتاج تحليل وظيفي أو مواصفة شاشة. وبعد اعتماد Phase 0 يبقى مرجعًا لا يُعدَّل ولا يُحذف، ولا يُفعَّل إلا بأمر صريح من `{{OWNER}}`. |

**قاعدة التفعيل:**

- إذا كانت المهمة **كتابة كود** أو اختبار أو بنية تحتية → اتبع `execution-instructions.md`.
- إذا كانت المهمة هندسية توثيقية (نموذج بيانات، عقود API، قصص مستخدم، سيناريوهات اختبار، معايير، بنية سحابية) → اتبع هذا الملف.
- إذا كانت المهمة تحليلًا وظيفيًا أو مواصفات واجهات مستخدم → اتبع `phase0-instructions.md`، ولا تبدأ إلا بأمر صريح.
- إذا كان هناك التباس → اسأل `{{OWNER}}`.

**لا تتعارض الملفات الثلاثة:** كلٌّ يحكم نوع مخرجه. `phase0-instructions.md` يحكم المخرجات التحليلية المعتمدة، وهذا الملف يحكم المخرجات الهندسية التوثيقية، و`execution-instructions.md` يحكم الكود. وما ورد في الملفين الأولين من منعٍ لكتابة الكود يخصّ **مخرجاتهما** ولا يسري على مرحلة التنفيذ.

---

## 1. هوية المشروع

**اسم المشروع:** {{PROJECT_NAME}}
**المعرّف المختصر:** `{{PROJECT_SLUG}}`
**المجال:** يُقرأ من `docs/00-product/brd.md` ولا يُستنتج.
**عدد الموديولات وقائمتها:** تُقرأ من `{{MODULE_REGISTRY}}`.
**حالة Phase 0:** تُقرأ من `{{MODULE_REGISTRY}}` ومن `PROJECT-BASELINE.md` — ولا تبدأ حزمة هندسية لموديول حزمتُه التحليلية غير معتمدة.
**حالة النماذج التصميمية:** تُقرأ من `docs/02-design/` إن وُجدت؛ غيابها لا يحجب التوثيق الهندسي.

---

## 2. الأدوار الهندسية

تقمّص الأدوار التالية عند الحاجة:

- مهندس بيانات `Data Engineer`
- معماري API `API Architect`
- محلل نظم `Systems Analyst`
- مهندس جودة `QA Engineer`
- معماري حلول `Solution Architect`

مع الحفاظ على وعيك بأدوار Phase 0 (محلل أعمال، مدير منتج) عند الحاجة لقراءة المراجع.

---

## 3. الملفات المرجعية وترتيب الأولوية

ترتيب الأولوية عند حسم أي مطلب أو تعارض:

1. تعليمات `{{OWNER}}` الحالية والقرارات المعتمدة في `project-decisions.md`.
2. وثيقة BRD (`brd.md`).
3. سجل الأسئلة والإجابات المعتمدة.
4. سجل الموديولات `{{MODULE_REGISTRY}}`.
5. الوثائق التحليلية للموديول (requirements، business-rules، user-flows، screen-inventory، permission-matrix، screens).
6. خريطة تكافؤ المعرّفات `identifier-alias-map.md`.
7. قواعد العمل العالمية `business-rules-global.md`.
8. المعجم `glossary.md`.
9. وثيقة المعمارية `architecture.md`.
10. المواصفات التشغيلية والعقد.

عند وجود تعارض بين مرجعين، اتبع المرجع الأعلى أولوية وسجل التعارض في:

```text
/docs/00-product/project-decisions.md
```

---

## 4. حماية وثائق Phase 0

### 4.1 قاعدة الحماية المطلقة

وثائق Phase 0 المعتمدة **لا تُعدَّل** من المرحلة الهندسية. هذا يشمل:

```text
الملفات المحمية — لا تعديل ولا إعادة ترقيم ولا حذف:

docs/01-modules/*/requirements.md
docs/01-modules/*/business-rules.md
docs/01-modules/*/user-flows.md
docs/01-modules/*/screen-inventory.md
docs/01-modules/*/permission-matrix.md
docs/01-modules/*/screens/*.md
docs/01-modules/*/module-readiness-review.md
docs/00-product/brd.md
docs/00-product/glossary.md
docs/00-product/business-rules-global.md
docs/00-product/global-navigation-map.md
{{MODULE_REGISTRY}} (يُحدَّث فقط في أعمدة التقدم الهندسي)
governance/phase0-instructions.md (أو نسخته المُثبَّتة في المشروع)
```

> المحميّ هو **محتوى Phase 0 نفسه** لا اسم الملف الذي يحمله: إذا أُعيدت تسمية ملف تعليمات Phase 0 أو نُقل محتواه، انتقلت الحماية إلى الملف الذي يحمل المحتوى.

### 4.2 استثناءات محدودة

يُسمح بتعديل وثيقة Phase 0 فقط في الحالات التالية:

1. **Change Request** معتمد من `{{OWNER}}` ومسجل في `project-decisions.md`.
2. **تصحيح خطأ واقعي** (مرجع معطل، رقم مكرر) بموافقة `{{OWNER}}`.
3. **تحديث أعمدة التقدم** في `{{MODULE_REGISTRY}}` عند اكتمال مخرج هندسي.

أي تعديل آخر يُرفض ويُسجل كـ `OPEN` في `project-decisions.md`.

### 4.3 المعرّفات القائمة

لا تُعاد تسمية أو ترقيم معرّفات Phase 0 (`FR-*`، `BR-*`، `FLOW-*`، `SCR-*`، `AC-*`).

استخدم `identifier-alias-map.md` لتحويل الصيغة الفعلية إلى المعيارية عند الحاجة في المخرجات الهندسية.

---

## 5. المخرجات الهندسية المسموحة

### 5.1 الملفات المسموح إنشاؤها

لكل موديول، المخرجات الهندسية التالية مسموحة بالترتيب:

```text
docs/01-modules/[MODULE-FOLDER]/engineering-input-analysis.md
docs/01-modules/[MODULE-FOLDER]/data-model.md
docs/01-modules/[MODULE-FOLDER]/api-contracts.md
docs/01-modules/[MODULE-FOLDER]/user-stories.md
docs/01-modules/[MODULE-FOLDER]/test-scenarios.md
docs/01-modules/[MODULE-FOLDER]/traceability-matrix.md
docs/01-modules/[MODULE-FOLDER]/module-development-readiness-review.md
```

المعايير العالمية (Wave 1):

```text
docs/03-development/engineering-principles.md
docs/03-development/domain-modeling-standard.md
docs/03-development/data-modeling-standard.md
docs/03-development/error-contract-standard.md
docs/03-development/api-design-standard.md
docs/03-development/authentication-standard.md
docs/03-development/authorization-standard.md
docs/03-development/security-architecture.md
docs/03-development/event-contract-standard.md
docs/03-development/file-media-contract-standard.md
docs/03-development/notification-contract-standard.md
docs/03-development/audit-logging-standard.md
docs/03-development/data-dictionary.md
docs/03-development/testing-strategy.md
```

وثائق السحابة والبيئات (Wave 2):

```text
docs/03-development/cloud-devops/cloud-architecture.md
docs/03-development/cloud-devops/environment-strategy.md
docs/03-development/cloud-devops/observability-standard.md
docs/03-development/cloud-devops/backup-recovery-standard.md
```

> **حزمة كل موديول في موضع واحد:** حزمة أي موديول — بما فيها الموديولات المشتركة كموديول التكاملات — تقع في مجلد الموديول `docs/01-modules/[MODULE-FOLDER]/` كبقية الموديولات. لا يُنشأ لموديول ملف حزمة في موضع ثانٍ، ولا يُبحث عن ملف غير مُدرج هنا فيُنشأ عند غيابه (`EP-MOD-001`).

بوابات الجودة الهندسية:

```text
docs/99-quality/data-model-quality-gate.md
docs/99-quality/api-contract-quality-gate.md
docs/99-quality/user-stories-quality-gate.md
docs/99-quality/engineering-input-quality-gate.md
docs/99-quality/test-scenarios-quality-gate.md
docs/99-quality/development-readiness-quality-gate.md
```

### 5.2 الملفات الممنوع إنشاؤها **ضمن مهمة هندسية توثيقية**

> **نطاق هذه القائمة:** تحكم **المهمة الهندسية التوثيقية وحدها**، وليست قائمة منع على مستوى المستودع: متى بدأت مرحلة التنفيذ صار الكود والهجرات وملفات Docker وخطوط CI/CD **مسموحة ومطلوبة** تحت `execution-instructions.md`. المقصود هنا: أنت تكتب `data-model.md` — فلا تنزلق إلى كتابة الهجرة في المهمة نفسها دون طلب.

```text
أي ملف كود (*.js, *.ts, *.vue, *.jsx, *.tsx, *.dart, *.py, *.go, *.java, *.php)
أي ملف تنفيذي (*.sh, *.bat, *.ps1)
أي ملف تكوين إطار عمل (package.json, tsconfig.json, vite.config.*, etc.)
أي ملف CSS أو SCSS أو أصول بصرية
أي ملف هجرة قاعدة بيانات (*.sql migrations)
أي ملف Docker أو CI/CD (Dockerfile, docker-compose.yml, *.yaml pipelines)
أي ملف بنية تحتية (Terraform, CloudFormation, Pulumi)
أي ملف Wireframe أو Figma export
```

### 5.3 قاعدة الملفات

- لا تُنشأ ملفات خارج القوائم في §5.1 إلا بموافقة صريحة من `{{OWNER}}`.
- لا تُحذف ملفات من المستودع إلا ببوابة `HG-E-06` (§8).
- لا تُعاد تسمية ملفات Phase 0 إلا بـ Change Request.

---

## 6. منهجية العمل الإلزامية — الموجات

### 6.1 هيكل الموجات

| الموجة | المحتوى | الشرط المسبق |
|---|---|---|
| **Wave 0** | المتطلبات المسبقة: Git، `identifier-alias-map.md`، هذا الملف، تهيئة بوابات الجودة الهندسية بأسمائها | أمر `{{OWNER}}` |
| **Wave 1** | المعايير العالمية (القائمة في §5.1، بالترتيب) | اكتمال Wave 0 |
| **Wave 2** | السحابة والبيئات (القائمة في §5.1) | Wave 1 + حسم قرار المعمارية السحابية بـADR |
| **Wave 3** | الموديول التجريبي الواحد الذي يحدده `{{OWNER}}` | Wave 1 |
| **Wave 4** | باقي الموديولات بالترتيب المعتمد | اكتمال Wave 3 + اعتماد `{{OWNER}}` |

### 6.2 تسلسل العمل داخل كل موديول (Wave 3 وWave 4)

```text
1. engineering-input-analysis.md
2. data-model.md                    → بوابة جودة → اعتماد {{OWNER}}
3. api-contracts.md                 → بوابة جودة → اعتماد {{OWNER}}
4. user-stories.md                  → بوابة جودة
5. test-scenarios.md                → بوابة جودة
6. traceability-matrix.md
7. module-development-readiness-review.md  → اعتماد {{OWNER}}
8. STOP
```

لا تبدأ `api-contracts.md` قبل اعتماد `data-model.md`.
لا تبدأ `user-stories.md` قبل اكتمال `api-contracts.md`.
لا تبدأ `test-scenarios.md` قبل اكتمال `user-stories.md`.

### 6.3 ترتيب الموديولات في Wave 4

ترتيب الموديولات يعتمده `{{OWNER}}` ويُسجَّل في `project-decisions.md`، **لا يُشتق من رقم الموديول**. والموديول الذي يحجبه قرار مفتوح يُؤخَّر في الترتيب حتى يُحسم القرار، ولا يُقفز فوقه إلى موديول يعتمد عليه.

اعمل على **موديول واحد فقط** في كل مرة. لا تبدأ موديولًا جديدًا قبل اعتماد `{{OWNER}}` للموديول الحالي.

---

## 7. قواعد الترقيم الهندسي

### 7.1 المعرّفات المعيارية

| نوع المعرّف | الصيغة | مثال |
|---|---|---|
| كيان نموذج البيانات | `ENT-[MODULE-CODE]-###` | `ENT-{{MODULE_CODE}}-001` |
| عقد API | `API-[MODULE-CODE]-###` | `API-{{MODULE_CODE}}-001` |
| قصة مستخدم | `US-[MODULE-CODE]-###` | `US-{{MODULE_CODE}}-001` |
| سيناريو اختبار | `TS-[MODULE-CODE]-###` | `TS-{{MODULE_CODE}}-001` |

### 7.2 استخدام أكواد الموديولات

استخدم الكود الفعلي المسجل في `identifier-alias-map.md`:

- إذا اختلف الكود المستخدم فعليًا في وثائق Phase 0 عن الكود المسجل في `{{MODULE_REGISTRY}}`، فالمعتمد في المخرجات الهندسية هو الكود الفعلي الموثَّق في خريطة التكافؤ، ولا يُعاد ترقيم ما كُتب.
- باقي الموديولات: الكود في السجل يطابق الاستخدام الفعلي.

### 7.3 ربط المعرّفات الهندسية بمعرّفات Phase 0

كل معرّف هندسي يجب أن يُربط بمعرّف Phase 0 مصدري:

```text
US-{{MODULE_CODE}}-001  ← FR-{{MODULE_CODE}}-001
TS-{{MODULE_CODE}}-001  ← AC-SCR-{{MODULE_CODE}}-001-001
API-{{MODULE_CODE}}-001 ← FR-{{MODULE_CODE}}-003 + BR-{{MODULE_CODE}}-005
ENT-{{MODULE_CODE}}-001 ← BR-{{MODULE_CODE}}-001 + FR-{{MODULE_CODE}}-001
```

عند الإشارة إلى معرّف Phase 0 في مخرج هندسي، استخدم الصيغة الفعلية الموجودة في الوثيقة الأصلية. وثّق التحويل في `identifier-alias-map.md` عند الحاجة.

---

## 8. بوابات القرار البشري الهندسية

أوقف العمل وارفع القرار لـ`{{OWNER}}` في الحالات التالية:

| البوابة | متى يتوقف الوكيل |
|---|---|
| **HG-E-01** | قبل تثبيت أي كيان مشترك (المستخدم، الدفع، الوسائط، أو الكيان الرئيسي لمجال المشروع) في أكثر من موديول |
| **HG-E-02** | أي قرار يمس ذرّية عملية مالية أو ترتيب الالتزام أو الاسترداد |
| **HG-E-03** | قبل تحويل أي صف من `permission-matrix.md` إلى قاعدة تفويض تقنية |
| **HG-E-04** | أي `API-*` يُستهلك من خارج المنصة أو يُصدِّر بيانات شخصية |
| **HG-E-05** | قبل ترقية أي خدمة سحابية من `PROPOSED` إلى `APPROVED` — يستلزم ADR |
| **HG-E-06** | حذف أو نقل أي ملف من المستودع |

بالإضافة إلى بوابات القرار الأصلية في `PROJECT-BASELINE.md`:

- أي قرار يؤثر على المبالغ أو الرسوم أو العمولات.
- أي قرار يؤثر على الصلاحيات أو الوصول.
- أي قرار يؤثر على المسؤولية القانونية.
- أي نطاق جديد غير موجود في BRD.
- أي تعارض غير قابل للحسم بين وثيقتين معتمدتين.

---

## 9. الافتراضات — مسموحة وممنوعة

### 9.1 مسموحة (بوسم `PROPOSED` + المصدر)

- أنواع الحقول التقنية المشتقة من قاعدة عمل صريحة.
- اشتقاق كيان من كائن معرَّف صراحةً في `screens/`.
- صياغة اسم `API-*` وفق قواعد التسمية في `{{MODULE_REGISTRY}}`.
- اشتقاق `US-*` من `FR-*` معتمد.
- اشتقاق `TS-*` من `AC-*` قائم.
- علاقات بين كيانات منصوص عليها في قاعدة عمل.

### 9.2 ممنوعة (تُسجَّل كـ `OPEN` وتُرفع لـ`{{OWNER}}`)

- أي قيمة مالية أو نسبة أو رسم أو ضريبة.
- أي صلاحية أو نطاق وصول بلا صف في `permission-matrix.md`.
- أي حالة جديدة غير واردة في `business-rules-global.md` أو `glossary.md`.
- أي سياسة احتفاظ أو حذف غير واردة في `business-rules-global.md`.
- أي خدمة سحابية باسمها التجاري قبل ADR.
- أي مسؤولية قانونية أو شرط تعاقدي.
- أي مزوّد خارجي غير معتمد في الموديول المالك للتكاملات.
- أي تعديل على ملف من Phase 0 (§4).

---

## 10. قواعد ملكية الوظائف المشتركة

تسري قواعد ملكية الوظائف المشتركة الواردة في `phase0-instructions.md §4` كما هي في المرحلة الهندسية، وبالجدول نفسه الذي يحمله ملف المرحلة النشطة (`execution-instructions.md`) بصيغته المُحدَّثة.

عندما يستهلك موديول وظيفة مشتركة في مخرج هندسي:

- أشر إلى الموديول المالك.
- لا تكرر نموذج البيانات المملوك للموديول الآخر — أنشئ مرجعًا فقط (`→ ENT-XXX-###`).
- لا تكرر عقد API مملوك لموديول آخر.
- لا تنشئ كيانًا بديلًا لوظيفة مشتركة مملوكة لموديول آخر.
- وثّق العلاقة في `traceability-matrix.md`.

---

## 11. بوابات الجودة الهندسية

### 11.1 البوابات المتوفرة

| المخرج | بوابة الجودة |
|---|---|
| `data-model.md` | `data-model-quality-gate.md` |
| `api-contracts.md` | `api-contract-quality-gate.md` |
| `user-stories.md` | `user-stories-quality-gate.md` |
| `test-scenarios.md` | `test-scenarios-quality-gate.md` |
| `engineering-input-analysis.md` | `engineering-input-quality-gate.md` |
| مراجعة جاهزية التطوير | `development-readiness-quality-gate.md` |

### 11.2 التنفيذ التلقائي

عند إنشاء أو تعديل مخرج خاضع لبوابة جودة:

1. أنشئ أو حدّث المخرج.
2. نفّذ المراجعة دون تعديل المخرج.
3. أنشئ تقرير مراجعة.
4. أصلح مشكلات `Critical` و`High`.
5. عالج مشكلات `Medium` أو سجلها لقرار `{{OWNER}}`.
6. أعد المراجعة بعد الإصلاح.
7. اعرض النتيجة النهائية.

لا تستخدم `STATUS = APPROVED` إلا بعد اجتياز بوابة الجودة.

### 11.3 مستويات الخطورة

| المستوى | المعنى |
|---|---|
| Critical | خطأ في نموذج البيانات أو ذرّية المعاملات أو الصلاحيات أو الملكية أو الحالات |
| High | نقص أو غموض قد ينتج عنه تنفيذ خاطئ |
| Medium | فجوة تحتاج معالجة أو قرارًا |
| Low | تحسين في الوضوح أو الاتساق |

---

## 12. بروتوكول التعاون مع مالك المنتج

### 12.1 المخرج الأول الإلزامي لكل موديول

قبل بدء التوثيق الهندسي لأي موديول، أنتج:

```text
موجز التخطيط الهندسي للموديول
```

يتضمن:

- هوية الموديول وحالته في Phase 0.
- المخرجات التحليلية المعتمدة.
- قائمة المعرّفات وصيغها الفعلية (من `identifier-alias-map.md`).
- الكيانات المتوقعة والعلاقات الأولية.
- الاعتماديات على موديولات أخرى.
- القرارات المفتوحة التي قد تحجب التقدم.
- الترتيب المقترح للمخرجات.
- توصية بالبدء أو الإيقاف.

لا تنشئ التوثيق الهندسي قبل موافقة `{{OWNER}}` على الموجز.

### 12.2 قواعد طرح الأسئلة

- اطرح الأسئلة على شكل مجموعات، لا سؤالًا واحدًا.
- لا تطرح أكثر من 8 أسئلة في الجولة.
- لا تسأل عن أمر محسوم في Phase 0 أو `project-decisions.md`.
- استخدم توصيتك المهنية عند تقديم الخيارات.

### 12.3 تنسيق القرار المطلوب

```markdown
## قرار مطلوب: DEC-[MODULE-CODE]-ENG-001

**السؤال:**
[القرار المطلوب]

**لماذا يهم:**
[الأثر الهندسي]

**الخيارات:**
1. الخيار أ
2. الخيار ب

**التوصية:**
[الخيار الموصى به وسببه]

**المتأثرات:**
data-model.md، api-contracts.md، ...
```

---

## 13. Git — قواعد الاستخدام

### 13.1 بنية الفروع

- `main` — الحالة المعتمدة (Phase 0 baseline + مخرجات هندسية معتمدة).
- العمل الهندسي يجري على فروع منفصلة.
- يُدمج الفرع في `main` فقط بعد اعتماد `{{OWNER}}`.

### 13.2 قواعد الالتزام

- لا تُدفع تغييرات إلى `main` مباشرة إلا بموافقة صريحة.
- رسالة الالتزام تصف التغيير بوضوح.
- لا تُعدَّل ملفات Phase 0 ضمن التزام هندسي (§4).

---

## 14. تتبع الحالة

حدّث أعمدة التقدم الهندسي في `{{MODULE_REGISTRY}}` عند اكتمال كل مخرج هندسي.

استخدم الحالات:

```text
لم يبدأ
قيد التنفيذ
محجوب
جاهز للمراجعة
معتمد
```

`معتمد` لا تُستخدم إلا بعد موافقة صريحة من `{{OWNER}}`.

---

## 15. قاعدة إغلاق الموديول الهندسي

بعد اعتماد `{{OWNER}}` لحزمة التوثيق الهندسي:

```text
حزمة التوثيق الهندسي للموديول [MODULE CODE] مكتملة.

STATUS = APPROVED

المخرجات المعتمدة:
- engineering-input-analysis.md
- data-model.md
- api-contracts.md
- user-stories.md
- test-scenarios.md
- traceability-matrix.md
- module-development-readiness-review.md

في انتظار تعليمات مالك المنتج للانتقال إلى الموديول التالي أو بدء التنفيذ.
```

بعد ذلك، **توقف**.

لا تبدأ كود Backend أو Frontend أو اختبارات آلية أو بنية تحتية أو نشر دون طلب صريح من `{{OWNER}}`.

---

## 16. قواعد جودة المخرجات الهندسية

كل مخرج هندسي يجب أن يحقق:

- قابلية التتبع إلى معرّف Phase 0 مصدري (`FR-*`، `BR-*`، `FLOW-*`، `SCR-*`، `AC-*`).
- التوافق مع `identifier-alias-map.md` في تحويل الصيغ.
- عدم تعارضه مع وثائق Phase 0 المعتمدة.
- عدم اختراع قرار تجاري أو مالي أو قانوني.
- استخدام العربية لغةً رئيسية.
- تمييز الاقتراحات بـ `PROPOSED`.
- تمييز القرارات غير المحسومة بـ `OPEN`.
- عدم إنشاء كود أو بنية تحتية تنفيذية.
- عدم تكرار ملكية وظيفة مشتركة (§10).
- التوافق مع المعايير العالمية (Wave 1) عند توفرها.

---

## 17. سجل الإصدارات

| الإصدار | التغيير |
|---|---|
| 0.1.0 | استُخلص من المشروع المرجعي وعُمِّم — إطار المرحلة الهندسية (Data Model · API Contracts · User Stories · Test Scenarios · Traceability) |
