---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/backend/app/Modules/_Example/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/backend/app/Modules/AuditLog/ (folder shape and provider pattern only — no business code)
language: ar
generalization: reviewed
---

# `_Example` — شكل مجلد الموديول

مجلد مرجعي يُظهر الشكل الذي يستعمله المشروع المرجعي لكل موديول. **لا كود أعمال فيه.** عند بدء موديول حقيقي: انسخ الشكل، وغيّر الاسم، واحذف `_Example` — أو أبقه خارج `bootstrap/providers.php`.

## اشتقاق الأسماء

| العنصر | القاعدة | مثال |
|---|---|---|
| مجلد الكود | اسم الموديول **كاملًا** بـPascalCase (`RS-012`)، مشتقًّا من مجلد التوثيق `docs/01-modules/<kebab-name>/` | `users-access` ⟵ `UsersAccess` |
| مزوّد الخدمة | `<ModuleName>ServiceProvider.php` في جذر المجلد | `UsersAccessServiceProvider` |
| بادئة الجداول | **كود** الموديول (ثلاثة أحرف) من `identifier-alias-map.md` (`RS-013`) | `usr_users` · `aud_audit_records` |
| قطاع مسار API | كود الموديول بحروف صغيرة بعد الإصدار (`API-005`) | `/api/v1/usr/...` |
| كود الخطأ | `ERR-<CODE>-<CAT>-###` (`ECS-006`) | `ERR-USR-BIZ-006` |

الخريطة الرسمية لمجلدات الموديولات داخل `scripts/arch-check.sh` — مجلد غير مسجَّل فيها يُرصد خرقًا.

## الشكل

```text
app/Modules/<ModuleName>/
├── Domain/                      النماذج (Eloquent) · التعدادات · قواعد المجال النقية
│   └── Models/
├── Application/                 الخدمات · حالات الاستخدام · المستمعون · الوظائف المجدولة
│   └── Services/
├── Infrastructure/              الهجرات (RS-014) · البذور · المستودعات · الموائمات
│   └── Migrations/              كل هجرة هنا — لا في database/migrations (RS-015)
├── Http/                        المتحكمات · الطلبات · الموارد · الوسائط · routes.php (RS-016)
│   ├── Controllers/
│   ├── Requests/
│   └── routes.php
├── Contracts/                   عقود داخلية للموديول (ليست العابرة — تلك في app/Shared/Contracts/)
└── <ModuleName>ServiceProvider.php
```

## ما يفعله المزوّد (انظر `ExampleServiceProvider.php`)

1. `register()` — يربط **العقود العابرة** التي ينشرها الموديول (`app/Shared/Contracts/<ModuleName>/*Interface`) بتنفيذاتها في `Application/`.
2. `boot()` — `loadMigrationsFrom(__DIR__.'/Infrastructure/Migrations')` · تسجيل محدِّدات المعدّل (`RateLimiter::for`) · تحميل `Http/routes.php` **داخل** مجموعة `api` وبادئة `api` — لأن `loadRoutesFrom` يسجّل خارج أي مجموعة، وبدونهما تفقد المسارات وسيط `api` ومعه `X-Trace-Id`.

## قواعد لا تُخالَف داخل الموديول

- لا استيراد من `App\Modules\<Other>\…` — العبور عبر `App\Shared\Contracts\` حصرًا (`RS-020` · `RS-023`)؛ Deptrac يُفشل البناء.
- لا `FOREIGN KEY` ولا `JOIN` عابرَين للموديولات (`RS-021` · `RS-022`) — المعرّف العابر إشارة منطقية.
- المتحكم رقيق: يتحقق (`FormRequest`) ويستدعي خدمة ويُعيد `ApiResponse::*` (`CS-016`). الخطأ **يُرمى** `DomainException` من الخدمة ولا يُبنى في المتحكم.
- كل ملف يُردّ إلى معرّف في حزمة الموديول الهندسية: هجرة ⟵ `ENT-*` · مسار ⟵ `API-*` · خدمة ⟵ `US-*` · اختبار ⟵ `TS-*`. كودٌ بلا معرّف = نطاق مُخترَع.
- قيود التعدادات تُفرض في المخطط (`CHECK`) لا في التطبيق وحده (`DD-019`).
- القيم القابلة للضبط تُقرأ من موديول الإعدادات عبر عقده (`CS-004`)؛ لا رقم مالي في كود أو بذرة بلا قرار مالك المنتج (`HG-I-01`).
