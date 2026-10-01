---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/backend/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/backend/ (app/Shared · bootstrap · deptrac.yaml · phpstan.neon · phpunit.xml · composer.json)
language: ar
generalization: reviewed
---

# Backend — النواة المشتركة لا تطبيق Laravel كامل

هذا المجلد **هيكل نواة مشتركة** يُنسخ فوق تطبيق Laravel جديد، وليس تطبيقًا يعمل وحده. ما ليس هنا — `artisan` · `config/*` · `public/` · `storage/` · `database/` — يأتي من `laravel new` (أو `composer create-project`)، ثم تُنسخ محتويات هذا المجلد فوقه.

## ما يحتويه

| المسار | الدور |
|---|---|
| `app/Shared/Exceptions/` | هرم الأخطاء المعتمد (`ECS-*`): فئات خمس · كود بصيغة `ERR-[MOD]-[CAT]-###` يُتحقَّق منه عند الإنشاء · مُصيِّر واحد يحوّل **كل** استثناء إلى بنية `ECS-003` |
| `app/Shared/Http/ApiResponse.php` | مغلّف الاستجابة الوحيد (`CS-016`): `success` · `successWithMeta` · `paginated` · `paginatedWith` · `successWithWarnings` · `error` · `noContent` |
| `app/Shared/Http/ApiSurface.php` | «هل هذا طلب API؟» — تعريف واحد لثلاثة مواضع |
| `app/Shared/Http/IdentityInput.php` | قاعدة `SEC-015` لرفض `<`/`>` في حقول الهوية |
| `app/Shared/Http/Middleware/AssignTraceId.php` | `X-Trace-Id` على كل استجابة API (`API-021`) — وسيط **عام** لا وسيط مجموعة |
| `app/Shared/OpenApi/DomainExceptionToResponseExtension.php` | يعلّم Scramble شكل أخطاء المجال كي ينشر العقد المولَّد حالات `403`/`422`/`502` لا `200/401/422` فقط |
| `app/Shared/Support/TraceContext.php` | معرّف التتبع — يُربط `scoped` لا `singleton` |
| `app/Shared/Support/ArabicText.php` | طيّ النص العربي للبحث (الهمزات · التاء المربوطة · الحركات) — أداة عامة لأي منصة عربية |
| `app/Shared/Contracts/README.md` | قاعدة العقود العابرة — الطريق الوحيد بين الموديولات |
| `app/Shared/Events/README.md` | قاعدة أحداث التكامل |
| `app/Modules/_Example/` | شكل مجلد الموديول كما يستعمله المشروع المرجعي — بلا كود أعمال |
| `app/Providers/AppServiceProvider.php` | ربط `TraceContext` وتثبيت خوادم OpenAPI |
| `bootstrap/app.php` · `bootstrap/providers.php` · `routes/api.php` | أسلاك النواة: المُصيِّر · الوسيط · الوكلاء الموثوقون · سجل المزوّدين · ملف التجميع الفارغ |
| `tests/TestCase.php` | البذر خاصية الحزمة لا الصنف · إفراغ الكاش قبل كل اختبار |
| `deptrac.yaml` · `phpstan.neon` · `phpunit.xml` | بوابات الحدود المعمارية · التحليل الساكن (level 8 + Larastan) · الاختبارات على MySQL بـ`failOn*` |
| `composer.json` | قوائم `require`/`require-dev` والسكربتات فقط |

**ما استُبعد عمدًا:** `Support/DisplayCalendar.php` من المشروع المرجعي — يثبّت منطقة عرض بعينها ويُحاكي عقدَ فلترةٍ خاصًّا؛ المنطقة الزمنية للعرض قرار منتج (`DD-021`) يُكتب في `config/app.php` لا في نواة مشتركة.

## الاعتماد على الملف الشخصي — الخطوات

```bash
# 1. تطبيق Laravel جديد
composer create-project laravel/laravel backend
cd backend

# 2. انسخ هذا المجلد فوقه (app/Shared · app/Modules/_Example · bootstrap · routes/api.php
#    · tests/TestCase.php · deptrac.yaml · phpstan.neon · phpunit.xml · dotfiles)
#    واستبدل composer.json بقوائم الاعتماديات هنا (مع إبقاء ما يحتاجه مشروعك).

# 3. {{PROJECT_SLUG}} في composer.json · app_test في phpunit.xml
```

ثم ثلاثة تعديلات في `config/scramble.php` (الملف يُنشر من الحزمة ولم يُنسخ هنا):

```php
'info' => ['version' => 'v1', 'title' => '{{PROJECT_NAME}} API', 'description' => ''],
'ui'   => ['title' => '{{PROJECT_NAME}} API', /* ... */],
'extensions' => [
    \App\Shared\OpenApi\DomainExceptionToResponseExtension::class,
],
```

> **لماذا العنوان مثبَّت لا مقروء من البيئة:** `backend/openapi.json` عقدٌ مُلتزَم تُقارَن به إعادةُ التوليد في بوابة OpenAPI. أي حقل يُقرأ من `APP_NAME` يجعل الملف يختلف باختلاف الجهاز — في المشروع المرجعي حمل العقد المنشور اسم المنصة على جهاز التطوير و«Laravel» في CI، ولم يكن ليظهر محليًا مهما تكرر التشغيل.

وفي `config/database.php` اتصال `cache` منفصل لنسخة Redis الثانية — القطعة في `docker/README.md §4.5`.

## القواعد التي تحكم كل سطر هنا

- `declare(strict_types=1)` في كل ملف PHP (`CS-010`).
- لا `env()` خارج `config/` (`CS-027`).
- لا `float` في سياق مالي (`CS-021`).
- القيم القابلة للضبط تُقرأ من موديول الإعدادات لا تُكتب في الكود (`CS-004`).
- كل مسار API يُعرَّف في `app/Modules/<Module>/Http/routes.php` ويُحمَّل من مزوّد الموديول (`RS-016`) — `routes/api.php` ملف تجميع فارغ من التعريفات، ووجوده هو ما يُنشئ مجموعة الوسائط `api`.
- كل هجرة داخل مجلد موديولها (`RS-014` · `RS-015`)، وبادئة كل جدول تطابق كود موديوله (`RS-013`).
- الاستهلاك العابر يمرّ عبر `app/Shared/Contracts/<Module>/` حصرًا (`RS-020` · `RS-023`) — Deptrac يُفشل البناء على استيراد مباشر.

## ثلاثة أعطاب مقيسة تحميها هذه الملفات

1. **`use Throwable;` في `bootstrap/app.php` يُطلق تحذير PHP 8.5 في كل استدعاء** — الملف بلا `namespace` فالاسم يُحلّ عالميًّا أصلًا، والاستيراد بلا أثر يُلوّث كل اختبار ويُسقط بوابة الاختبارات عبر «التحذير فشل». لا تُعِد إضافته.
2. **`CACHE_STORE=array` في `phpunit.xml` لا يسري داخل حزمة الاختبار** — `<env>` لا يكتب فوق متغيّر موجود، و`compose.test.yaml` يُصدِّر `redis`. فالاختبارات تعمل على Redis حقيقي يبقى بعد التشغيل؛ `TestCase::setUp` يُفرغه قبل كل اختبار. وهذا مقصود: الكاش يُختبر على المحرّك الذي يُنشر.
3. **الاختبارات على MySQL لا SQLite** — SQLite بلا مُحفِّزات، فيمرّ ضمان append-only لسجل التدقيق أخضر والقيد غير موجود.
