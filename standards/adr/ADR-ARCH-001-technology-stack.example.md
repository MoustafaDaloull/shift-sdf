---
document_type: ADR Example
framework: Shift SDF
file: standards/adr/ADR-ARCH-001-technology-stack.example.md
title: الحزمة التقنية الأساسية
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/docs/03-development/adr/ADR-ARCH-001-technology-stack.md
language: ar
generalization: reviewed
---

<!-- مثال: ADR الحزمة التقنية للملف التعريفي الافتراضي laravel-react. يُنسخ إلى docs/03-development/adr/ADR-ARCH-001-technology-stack.md ويُعدَّل بما يخص المشروع -->

```yaml
---
adr_id: ADR-ARCH-001
title: الحزمة التقنية الأساسية
status: APPROVED
decision_date: {{YYYY-MM-DD}}
language: ar
owner: {{OWNER}}
supersedes: "بند «العناصر PROPOSED تبقى مقترحة» في قرار اعتماد خط الأساس المعماري — لم يعد ساريًا للعناصر الستة أدناه"
superseded_by: "—"
registered_in: docs/00-product/project-decisions.md (تحت قرار اعتماد خط الأساس المعماري)
---
```

# ADR-ARCH-001 — الحزمة التقنية الأساسية

> القواعد المرتبطة بحزمة تقنية بعينها تُطبَّق عبر ملف تعريف الحزمة `profiles/<name>/`؛ الافتراضي `laravel-react`. هذا المثال هو ADR ذلك الملف التعريفي.

---

## 1. الحالة

```text
APPROVED — {{YYYY-MM-DD}}
```

**العناصر المعتمدة:** Modular Monolith · Laravel على PHP · MySQL · Redis · React + TypeScript + Vite · فصل Frontend/Backend · REST API الواجهة الوحيدة · Docker للبيئة المحلية.

---

## 2. السياق

وثيقة المعمارية (`architecture.md`) وصفت في إصدارها الأول حزمة تقنية بحالة `Draft`. تدقيق الانتقال الهندسي أعاد تصنيف العناصر البنيوية `PROPOSED` ونصّ صراحةً:

> «جميع العناصر المصنفة `PROPOSED` (النمط المعماري، محرك قاعدة البيانات، أسماء الخدمات السحابية المحددة) تبقى مقترحة لا معتمدة — **لا يُبنى عليها دون ADR**.»

**النتيجة العملية:** لا يمكن كتابة سطر واحد من الكود. الموديول لا يُهندَس بلا معرفة محرك قاعدة البيانات، ولا تُكتب المعايير بلا معرفة النمط المعماري. هذا الـADR هو ما يرفع ذلك الحجب.

---

## 3. الخيارات المدروسة

| # | الخيار | الوصف المختصر |
|---|---|---|
| 1 | **Modular Monolith + Laravel REST API + React SPA + MySQL + Redis** | تطبيق واحد منظَّم موديولات مستقلة منطقيًا، وواجهة مفصولة تستهلك REST فقط |
| 2 | Full Microservices | خدمات مستقلة من اليوم الأول |
| 3 | Laravel Blade (خلفية تُصيّر الواجهة) | Server-Side Rendering بلا فصل |
| 4 | PostgreSQL بدل MySQL | محرك بديل |
| 5 | قاعدة بيانات لكل موديول | فصل تخزيني مبكر |

---

## 4. القرار

> اعتماد Frontend مستقل (React + TypeScript + Vite — SPA) مع Backend مستقل (Laravel REST API على PHP — Modular Monolith Architecture) وقاعدة بيانات MySQL وRedis للـ Cache/Sessions/Queue، وحزمة Docker للبيئة المحلية.

### 4.1 العناصر المحسومة

| # | العنصر | قبل | بعد |
|---|---|---|---|
| 1 | النمط المعماري | `PROPOSED` | **Modular Monolith** ✅ |
| 2 | محرك قاعدة البيانات | `PROPOSED` | **MySQL** ✅ |
| 3 | إطار العمل الخلفي | `PROPOSED` | **Laravel على PHP** ✅ |
| 4 | الواجهة الأمامية | `PROPOSED` | **React + TypeScript + Vite** ✅ |
| 5 | Cache / Sessions / Queue | `PROPOSED` | **Redis** ✅ |
| 6 | فصل Frontend / Backend | `PROPOSED` | ✅ |
| 7 | بيئة التطوير والاختبار | `PROPOSED` | **Docker Compose** (حزمة محلية + حزمة اختبار معزولة) ✅ |

---

## 5. السبب

- تبسيط التطوير وتقليل التعقيد التقني.
- فصل المسؤوليات بين الواجهة والخلفية.
- تسهيل تطوير تطبيقات الموبايل مستقبلًا عبر نفس REST APIs.
- إمكانية استبدال الواجهة الأمامية دون تعديل Backend.
- سهولة التكامل مع الخدمات الخارجية عبر REST APIs.
- تقليل تكلفة التشغيل في MVP مقارنة بـ Full Microservices.
- توافق مع هدف الإطلاق المستهدف.

---

## 6. البدائل المرفوضة

| البديل | لماذا رُفض |
|---|---|
| **Full Microservices** | تكلفة تشغيل وتعقيد لا يبررهما حجم المرحلة الأولى. `EP-ARCH-004` يشترط الوعي بالتكلفة، و`EP-ARCH-003` يحفظ إمكانية الفصل لاحقًا بلا دفع ثمنها الآن |
| **PostgreSQL** | MySQL LTS مدعوم طويلًا وتقدّمه قواعد البيانات المُدارة إصدارًا مستقرًا؛ ولا ميزة من مزايا PostgreSQL في هذا النطاق تبرّر الانتقال |
| **Laravel Blade (خلفية تُصيّر الواجهة)** | يُلغي فصل الواجهة عن الخلفية، فيمنع تطبيق الموبايل مستقبلًا من استهلاك العقود نفسها — وهو غرض مُعلَن في §5 |
| **قاعدة بيانات لكل موديول** | تقتل الاتساق المعاملاتي داخل الموديول الواحد وتفرض تكلفة تشغيل مبكرة. الفصل يتحقق بحدود الكود (`RS-020`..`RS-025`) لا بفصل التخزين |

---

## 7. الأثر (التبعات)

| المجال | الأثر |
|---|---|
| Frontend | واجهة مستقلة بالكامل — React + TypeScript + Vite. لا Laravel Blade |
| Backend | Laravel REST API — Service Layer + Repository Pattern. Sanctum للمصادقة (رموز Bearer مبهمة — `AUTH-010`) |
| Database | MySQL |
| Cache / Sessions | Redis لجميع احتياجات Cache وSessions وQueue وRate Limiting |
| Deployment | نشر مستقل لكل مكوّن (Frontend / Backend / Database / Redis) |
| Environment | Docker Compose للبيئة المحلية وحزمة اختبار معزولة بقاعدة مستقلة |
| Security | جميع الاتصالات عبر HTTPS. Backend يقدم JSON فقط |
| API | REST API هو الواجهة الوحيدة بين Frontend وBackend |
| CI/CD | Pipeline مستقل لكل من Frontend وBackend |
| Testing | اختبار Backend عبر API Tests بشكل مستقل. اختبار Frontend ضد Mock API |
| Documentation | تحديث `architecture.md` والمعايير الهندسية المتأثرة |

---

## 8. الأسئلة المغلقة

| السؤال | الإجابة التي يُغلقها هذا القرار |
|---|---|
| هل يُبنى النظام Monolith أم Microservices؟ | Modular Monolith قابل للفصل لاحقًا |
| ما محرك قاعدة البيانات؟ | MySQL حصرًا |
| هل تُصيَّر الواجهة من الخلفية؟ | لا — SPA مفصولة تستهلك REST فقط |
| ما مكدس الواجهة؟ | React + TypeScript + Vite |
| أين تعيش الجلسات والطوابير والكاش؟ | Redis |

**ما يبقى مفتوحًا بعد هذا القرار** (يُسجَّل بنودًا `OPEN` في `project-decisions.md`): الخدمات السحابية المحددة (الاستضافة · الرسائل · الأسرار · السجل) · استراتيجية الـCaching التفصيلية · سياسة إهمال إصدارات API.

---

## 9. الحالة التنفيذية

> يُملأ بعد التنفيذ ويُحدَّث بالقياس لا بالادّعاء.

| العنصر | التحقّق |
|---|---|
| Modular Monolith | `{{STATUS}}` — `app/Modules/` بطبقاته · بوابة الحدود المعمارية (`AS-031`) |
| MySQL | `{{STATUS}}` — الاختبارات على MySQL لا SQLite |
| Laravel على PHP | `{{STATUS}}` |
| Redis | `{{STATUS}}` — مثيلان مفصولان (كاش · طوابير) |
| فصل Frontend/Backend | `{{STATUS}}` — `backend/` و`frontend/` منفصلان بحاويتين |
| React + TypeScript + Vite | `{{STATUS}}` |
| Docker Compose | `{{STATUS}}` — الإقلاع من نسخة نظيفة هو الاختبار المعتبر |

---

## 10. المراجع

| المرجع | العلاقة |
|---|---|
| قرار اعتماد خط الأساس المعماري (`DEC-ARCH-NNN`) | القرار الأب — هذا الـADR يُسقط بنده الخاص بالعناصر `PROPOSED` |
| `architecture-template.md` | التنزيل التفصيلي (الحزمة التقنية · القرارات المعمارية) |
| `PROJECT-BASELINE.md` | حالة العناصر المتبقية |
| `engineering-principles.md` `EP-ARCH-001` | يُرقّى إلى `MANDATORY` بموجب هذا الـADR |
| `profiles/laravel-react/` | ملف تعريف الحزمة المنفِّذ لهذا القرار |

---

## 11. سجل الإصدارات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| 0.1.0 | — | extracted from the reference project |
