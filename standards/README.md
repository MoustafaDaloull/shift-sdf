---
document_type: Framework Guide
framework: Shift SDF
file: standards/README.md
version: 0.1.0
status: DRAFT
language: ar
---

# المعايير الهندسية

أربعة عشر معيارًا عالميًا تحكم كل سطر كود، وقالب للمعمارية وقالب لسجل القرار المعماري (ADR). تُنسخ إلى `docs/03-development/` في المشروع الجديد وتصير **محميّة** بعد اعتمادها: لا تُعدَّل إلا بطلب تغيير معتمد.

كل معيار يحمل قواعد مرقّمة بمعرّف ثابت ومستوى إلزام (`MANDATORY` · `RECOMMENDED`) وملاحظة فرض. المعرّف هو ما يُحال إليه من الكود والمراجعة والبوابات، ولا يُعاد ترقيمه.

## الموجات

| الموجة | الملفات | بادئة القواعد | ما تحكمه |
|---|---|---|---|
| **1 — المعايير العالمية** | `engineering-principles.md` | `EP-<AREA>-*` | المبادئ الحاكمة لكل قرار هندسي |
| | `domain-modeling-standard.md` | `DMS-*` | الكيانات والتعدادات وقواعد المجال والملكية |
| | `data-modeling-standard.md` | `DMOD-*` | الجداول والقيود والهجرات والبادئات |
| | `error-contract-standard.md` | `ECS-*` | هرم الأخطاء وعقد الاستجابة |
| | `api-design-standard.md` | `API-*` | المسارات والإصدار والشكل الموحّد وOpenAPI |
| | `authentication-standard.md` | `AUTH-*` | الهوية والجلسات وOTP |
| | `authorization-standard.md` | `AUTHZ-*` | التفويض ومصفوفة الصلاحيات |
| | `event-contract-standard.md` | `EVT-*` | أحداث التكامل بين الموديولات |
| | `file-media-contract-standard.md` | `FMC-*` | رفع الوسائط ومعالجتها |
| | `notification-contract-standard.md` | `NTF-*` | الإشعارات وقنواتها |
| | `audit-logging-standard.md` | `AUD-*` | سجل التدقيق Append-only على مستويين |
| | `testing-strategy.md` | `TST-*` | هرم الاختبار والوسم بالسيناريو |
| | `security-architecture.md` | `SEC-*` | الأسرار والنقل والتخزين |
| **2 — أساس التنفيذ** | `repository-structure.md` | `RS-*` | بنية المستودع ومجلدات الموديول والعقود المشتركة |
| | `coding-standards.md` | `CS-*` | معايير الكتابة: الأنواع الصارمة، لا `env()` خارج التكوين، لا `float` مالي، القيم القابلة للضبط من موديول الإعدادات |
| | `automation-strategy.md` | `AS-*` | البوابات الآلية وتسلسلها وعتباتها |
| **المعمارية** | `architecture-template.md` | — | خط الأساس: Modular Monolith، الحدود، النواة المشتركة |
| | `adr/` | `ADR-*` | قالب ADR وعملية الاعتماد ومثال ADR الحزمة الافتراضية |

## قاعدتان

1. **القواعد المرتبطة بحزمة تقنية بعينها** تُطبَّق عبر ملف تعريف الحزمة `profiles/<name>/`؛ المعيار يذكر القاعدة والملف التعريفي يذكر الأداة.
2. **المعيار يحكم الحزمة الهندسية للموديول، والحزمة تحكم الكود.** عند تعارض معيار مع حزمة موديول معتمدة يُرفع التعارض ولا يُحسم بالاجتهاد.
