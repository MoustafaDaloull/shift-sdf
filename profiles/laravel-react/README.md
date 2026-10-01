---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/ (docker · .github · Makefile · backend/app/Shared · backend config · frontend toolchain)
language: ar
generalization: reviewed
---

# الملف الشخصي `laravel-react` — الحزمة التقنية الافتراضية لإطار Shift SDF

**ما هو:** الجزء الخاص بالحزمة التقنية من الإطار — كل ما ينسخه مشروع جديد ليحصل على **سلسلة الأدوات وحزمة الحاويات وخط التكامل وهيكل الكود المشترك** نفسها التي بُني عليها المشروع المرجعي، **بلا موديول أعمال واحد**. ما في الإطار من حوكمة ومعايير وقوالب (`governance/` · `standards/` · `templates/` · `scripts/`) يعمل فوق هذا الملف الشخصي؛ وهذا الملف الشخصي هو ما يجعل تلك البوابات قابلة للتشغيل على كود حقيقي.

**ما ليس هو:** تطبيقًا يعمل وحده. `backend/` نواة مشتركة تُنسخ فوق `laravel new`، و`frontend/` سلسلة أدوات تُنسخ فوق `npm create vite`، ونظام التصميم **لكل مشروع** ولا يأتي من هنا.

---

## 1. الحزمة التقنية

محسومة كما هي؛ لا يُعاد تقييمها عند اعتماد الملف الشخصي.

| الطبقة | المعتمد |
|---|---|
| النمط المعماري | Modular Monolith — موديول لكل مجلد، والعبور بالعقود حصرًا |
| Backend | Laravel على PHP 8.x (الصورة تثبّت 8.5) |
| قاعدة البيانات | **MySQL 8.4 LTS** حصرًا — `utf8mb4_unicode_ci` لصحة العربية |
| التخزين المؤقت والطوابير | **Redis بنسختين منفصلتين**: `redis` (طابور + جلسات · `noeviction` · مستمرّة) و`redis-cache` (كاش + تحديد معدّل · `allkeys-lru` · مؤقتة) |
| Frontend | **React 19 + TypeScript + Vite** + react-router 7 |
| نظام التصميم | **بناء داخلي** فوق `design-system.md` الخاص بالمشروع — لا مكتبة مكوّنات تفرض مظهرها |
| جداول البيانات | مكتبة **headless** — المنطق بلا ترميز، والترميز والأصناف من المشروع |
| فحص Frontend الساكن | **ESLint** (قواعد TypeScript + `react-hooks` + منع `innerHTML`) + **`tsc --noEmit`** · `--max-warnings=0` |
| اختبارات المكوّنات | **Vitest** + **React Testing Library** (`jsdom`) |
| التدفقات والمطابقة البصرية والإتاحة | **Playwright — Chromium وحده** · **axe-core** عبر Playwright |
| توثيق API | **Scramble** — OpenAPI مُولَّد من الكود، ملف واحد مُلتزَم يُقارَن بإعادة التوليد |
| التنسيق · التحليل الساكن · الحدود | **Pint** · **PHPStan level 8 + Larastan** · **Deptrac** |
| الاختبارات الخلفية | **PHPUnit** على MySQL (لا SQLite) في حزمة معزولة بـ`failOnWarning/Risky/Notice` |
| البيئة | **Docker Compose** — تسع خدمات · أربع طبقات: `dev` · `test` · `ci` · `prod` |

---

## 2. ما يحتويه الملف الشخصي

```text
profiles/laravel-react/
├── README.md                     ← هذا الملف
├── .env.example                  ← كل متغيّر بيئة تقرأه الحزمة، بقيم وهمية
├── .dockerignore · .gitattributes · Makefile
├── .github/                      ← ci.yml · PULL_REQUEST_TEMPLATE.md · CODEOWNERS
├── docker/                       ← compose/{yaml,dev,test,ci,prod} · php · node · nginx · mysql · redis · mailpit · README.md
├── backend/                      ← النواة المشتركة (app/Shared) · bootstrap · deptrac · phpstan · phpunit · composer.json · _Example
└── frontend/                     ← package.json · tsconfig · vite · eslint · playwright · src/shared/{api,hooks} · tests/support
```

كل مجلد يحمل `README.md` خاصًّا به يشرح محتواه وأسباب كل قرار فيه: [`docker/README.md`](docker/README.md) · [`backend/README.md`](backend/README.md) · [`frontend/README.md`](frontend/README.md).

### تخطيط مجلدات الموديول

```text
backend/app/Modules/<ModuleName>/            اسم الموديول كاملًا PascalCase
├── Domain/                                  النماذج · التعدادات · قواعد المجال
├── Application/                             الخدمات · حالات الاستخدام · المستمعون
├── Infrastructure/Migrations/               الهجرات داخل الموديول — لا في database/migrations
├── Http/                                    المتحكمات · الطلبات · الموارد · routes.php
├── Contracts/                               عقود داخلية للموديول
└── <ModuleName>ServiceProvider.php          يربط العقود العابرة ويحمّل الهجرات والمسارات

backend/app/Shared/
├── Contracts/<OwnerModule>/                 الطريق الوحيد بين الموديولات (واجهة + DTO)
├── Events/                                  أحداث التكامل (final readonly)
├── Exceptions/                              هرم الأخطاء + المُصيِّر الواحد
├── Http/                                    ApiResponse · ApiSurface · IdentityInput · Middleware/AssignTraceId
├── OpenApi/                                 امتداد Scramble لأخطاء المجال
└── Support/                                 TraceContext · ArabicText

frontend/src/
├── app/                                     الموجّه · التخطيطات · routes.tsx للنظام
├── modules/<module-kebab>/                  شاشات الموديول · api.ts · routes.tsx
├── shared/{api,components,format,hooks,screens}/
└── styles/                                  توكنز المشروع وأنماطه (لا تأتي من هنا)

frontend/tests/
├── unit/        Vitest + RTL
├── e2e/         Playwright — التدفقات
├── visual/      Playwright — المطابقة البصرية (+ *-snapshots/ مُلتزَمة)
├── a11y/        Playwright + axe-core
├── integration/ Playwright ضد الخلفية الحقيقية
└── support/     مساعدات مشتركة
```

---

## 3. ثلاثة قيود في Playwright تعلّمناها بالخسارة

1. **Chromium من حزمة توزيعة Alpine، لا من Playwright.** حزمة Playwright مبنيّة على glibc: تُثبَّت على Alpine ثم لا تُقلع. البديل حمل صورة ثانية بـDebian لبوابة واحدة، فاختير متصفح التوزيعة نفسه ويُسمّى صراحةً في `playwright.config.ts`. النتيجة المُعلَنة لا المكتشَفة: محرّك العرض هو ما تشحنه الحزمة، فخطوط الأساس تُولَّد **داخل الحاوية حصرًا**، وإعادة بناء الصورة على Alpine أحدث قد تستلزم إعادة توليدها — فرقًا مرئيًّا قابلًا للمراجعة.
2. **خطوط `ttf-dejavu` شرط صحة لا زينة.** بدونها يصير كل حرف عربي مربّعًا، فتقارن بوابة المطابقة البصرية خطوط أساس لصفحة غير مقروءة **وتُعلن النجاح**. كل خط يُضاف مُدخلٌ آخر تعتمد عليه خطوط الأساس، فلا يُضاف بلا سبب.
3. **`workers: 1` مثبَّت.** الحقل الغائب يشتقّه Playwright من نوى المضيف (`ceil(cores/2)`)، فتُشغّل البوابة عددًا مختلفًا من الاختبارات المتوازية على كل جهاز — بوابةٌ ليست البوابةَ نفسَها في مكانين. وبأربعة عمّال سقط **الاختبار الأول في كل ملف** (واحد لكل عامل عند أول تنقّل متزامن): visual 14/18 · a11y 33/37. بعامل واحد 18/18 و37/37 بكلفة 36 ثانية، والاختبار المفرد **أسرع**. لا يُرفع: ما يتغيّر هو كم يعمل معًا لا ما يُفحص.

## 4. تصليب بوابة المطابقة البصرية

| الإعداد | القيمة | الثغرة التي أغلقها |
|---|---|---|
| `threshold` | `0` | افتراض Playwright `0.2` لكل بكسل أبطل العتبة كلها: نُقل لون العلامة التجارية درجةً فمرّت البوابة خضراء — لم يُحسب بكسل مختلفًا أصلًا |
| `maxDiffPixelRatio` | `0.001` | «شبه صفر» رقمًا؛ لكن 0.1% من 1280×800 = 1024 بكسل، والحروف العربية رفيعة: إعادة كتابة `<h1>` كامل حرّكت 587 بكسل ومرّت |
| `maxDiffPixels` | `100` | سقف مطلق بجوار النسبة؛ Playwright يُفشل عند تجاوز **أيٍّ** منهما فيحكم الأصغر — أُثبت بخرق لا بتقدير |

**وخطوط الأساس تُولَّد داخل الحاوية حصرًا** وتُلتزم في `tests/**/*-snapshots/`، ولا تُحدَّث تلقائيًّا أبدًا — بمقارنة وتقرير وموافقة مالك المنتج.

**القاعدة فوق الثلاثة:** البوابة لا تُعدّ عاملة قبل أن تفشل عمدًا. كل بوابة في هذا الملف الشخصي أُثبتت بخرق متعمَّد في المشروع المرجعي، وإحداها (البصرية) **مرّت على خرقها أولًا** — وهذا بالضبط لماذا الإثبات شرط لا طقس.

---

## 5. ما يتوقعه الملف الشخصي من بقية الإطار

| ما يستدعيه | من أين |
|---|---|
| `bash scripts/quality.sh` (+ `--with-tests` · `--list-shards` · `--shard=<name>` · الأوامر المفردة `fmt` `stan` `arch` `routes` `fe-static` `secrets` `openapi` `tests`) | `scripts/` في الإطار — **مصدر الحقيقة الوحيد لتسلسل الفحوص**؛ `Makefile` و`ci.yml` يفوّضان إليه ولا يعرّفان تسلسلًا ثانيًا |
| `scripts/protected-paths-check.sh` | وثائق التحليل لا تتغيّر بلا Change Request — تعمل في مهمة `plan` |
| `scripts/route-check.sh` · `scripts/arch-check.sh` · `scripts/secret-scan.sh` · `scripts/sync-check.sh` | بوابات المسارات · الحدود · الأسرار · المزامنة — يستدعيها `quality.sh` |
| `scripts/hooks/pre-commit` · `post-commit` | يثبّتهما `make hooks` |
| المعايير (`RS-*` · `CS-*` · `AS-*` · `ECS-*` · `API-*` · `SEC-*` · `DD-*`) | `standards/` — المعرّفات المذكورة في تعليقات الكود هنا تُحيل إليها |

---

## 6. كيف يُعتمد الملف الشخصي

```bash
# 0. مستودع جديد من قالب الإطار (الحوكمة والمعايير والسكربتات)، ثم:

# 1. الجذر: الحزمة والبيئة
cp -r profiles/laravel-react/{docker,.github,Makefile,.env.example,.dockerignore,.gitattributes} ./
#    استبدل {{PROJECT_SLUG}} · {{PROJECT_NAME}} · {{OWNER_HANDLE}} في كل الملفات:
grep -rln '{{PROJECT_SLUG}}\|{{PROJECT_NAME}}\|{{OWNER_HANDLE}}' . | xargs sed -i 's/{{PROJECT_SLUG}}/myproj/g; s/{{PROJECT_NAME}}/My Project/g; s/{{OWNER_HANDLE}}/github-handle/g'
#    ثم TODO-GENERALIZE (grep -rn TODO-GENERALIZE) — كل موضع يحتاج قيمة من المشروع.

# 2. Backend
composer create-project laravel/laravel backend
cp -r profiles/laravel-react/backend/* profiles/laravel-react/backend/.editorconfig backend/
#    + التعديلات الثلاثة في config/database.php و config/scramble.php (backend/README.md)
git update-index --chmod=+x docker/mysql/initdb/01-init-databases.sh   # بت التنفيذ حاسم

# 3. Frontend (داخل حاوية node)
cp .env.example .env && docker compose --project-directory . -f docker/compose/compose.yaml -f docker/compose/compose.dev.yaml up -d --wait
docker compose ... exec node npm create vite@latest . -- --template react-ts
cp -r profiles/laravel-react/frontend/* profiles/laravel-react/frontend/.gitignore frontend/

# 4. أول عمل: البوابات قبل أول شريحة
bash scripts/quality.sh            # يجب أن تخضرّ على هيكل فارغ
#    ثم أثبِت كل بوابة بخرق متعمَّد وسجّل الدليل — قبل أول سطر أعمال.
```

**قواعد الاعتماد:**

- **لا تُعدَّل المعايير لتوافق الملف الشخصي.** إن تعارضا فالمعيار هو المرجع، والفرق يُسجَّل ويُرفع.
- **لا قيمة مالية ولا قابلة للضبط في الكود.** القيم المالية غير مبذورة عمدًا؛ غيابها مقصود ومُختبَر.
- **لا سر في المستودع.** `.env` وهمي بالقالب؛ الإنتاج من مدير أسرار عبر `${VAR:?}`.
- **بيئة التشغيل محلية وCI حصرًا** حتى قرار نشر صريح. `compose.prod.yaml` يبني الصور ويُثبت أنها تعمل؛ ملفات النشر إلى منصة بعينها **خارج** الملف الشخصي عمدًا (المشروع المرجعي حملها في `docker/cloudrun/` و`docker/cloudflare/` ولم تُنقل).

---

## 7. ما استُبعد من المشروع المرجعي ولماذا

| المستبعَد | السبب |
|---|---|
| `docker/cloudrun/` · `docker/cloudflare/` | نشر إلى منصة بعينها — قرار لكل مشروع بـADR مستقل |
| موديولات الأعمال (22) وعقودها (~90 واجهة) وأحداثها (5) | كود أعمال؛ يبقى الشكل (`_Example`) والقاعدة (`Contracts/README.md` · `Events/README.md`) |
| `ffmpeg` في صورة PHP · مونت وثائق قانونية · متغيّرات بوابة دفع | متطلبات موديولات بعينها |
| `Support/DisplayCalendar.php` | يثبّت منطقة عرض ويُحاكي عقد فلترة خاصًّا — قرار منتج |
| شاشات الواجهة · الموديولات · التوكنز والأنماط · المكوّنات · fixtures · `seo/` · `format/dateTime.ts` · `useResultsScroll` · `profilePhotoSignal` | نظام التصميم لكل مشروع؛ والمساعدات المذكورة مقترنة به أو بنقاط API خاصة |
| `pint.json` | غير موجود في المصدر — Pint يعمل بإعداد Laravel الافتراضي |
| carve-out تأطير `/media/` في nginx | خاص بعارض PDF؛ الملف الشخصي يشحن `DENY` و`frame-ancestors 'none'` ويشرح كيف يُستثنى مسار |

---

## 8. سجل الإصدارات

| الإصدار | التاريخ | التغيير |
|---|---|---|
| 0.1.0 | 2026-10-01 | استخلاص أولي من المشروع المرجعي — DRAFT بانتظار مراجعة مالك الإطار |
