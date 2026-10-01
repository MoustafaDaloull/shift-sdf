---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/frontend/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/frontend/ (toolchain configs · src/shared/{api,hooks} · tests/support · tests/warmup.setup.ts)
language: ar
generalization: reviewed
---

# Frontend — سلسلة الأدوات والهيكل المشترك، لا التطبيق

هذا المجلد **سلسلة أدوات + هيكل مشترك** يُنسخ فوق تطبيق Vite جديد، وليس تطبيقًا يعمل وحده. لا شاشة فيه ولا موديول ولا توكنز تصميم: نظام التصميم **لكل مشروع** ويُبنى داخليًّا فوق `design-system.md` الخاص به.

## ما يحتويه

| المسار | الدور |
|---|---|
| `package.json` | React 19 · react-router 7 · Vite 7 · TypeScript 5.9 · Vitest + RTL · Playwright + axe-core · ESLint 9 — بلا مكتبة مكوّنات تفرض مظهرها، وجدول البيانات يُختار **headless** |
| `tsconfig.json` | `strict` + `noUncheckedIndexedAccess` + `verbatimModuleSyntax`؛ مجلدات Playwright مستثناة لأنها لا تحمل أنواع Node |
| `vite.config.ts` | الخادم على `0.0.0.0` (حاوية) + إعداد Vitest (`jsdom` · `testTimeout: 20s` كاشفَ تعليق لا ميزانيةَ أداء) |
| `eslint.config.js` | قواعد TypeScript + `react-hooks` + منع `dangerouslySetInnerHTML` وإسناد `innerHTML` بالصياغة (`SEC-015`) + `no-console` |
| `playwright.config.ts` | أربعة مشاريع (`e2e` · `visual` · `a11y` · `integration`) + مشروع `warmup` تمهيدي · القيود الثلاثة والعتبات الثلاث (أدناه) |
| `.gitignore` | ما يُهمل وما **لا** يُهمل (خطوط الأساس تُلتزم) + فخّ نمط الأسرار |
| `index.html` | `lang="ar" dir="rtl"` |
| `src/shared/api/` | `client.ts` (لا يرمي أبدًا — اتحاد مميَّز) · `errors.ts` (مغلّف `ECS-003` كأنواع) · `sessionExpiry.ts` (انتهاء الجلسة يُعالَج مرة واحدة لكل الطلبات) · `directUpload.ts` (رفع مباشر بتقدّم عبر XHR) |
| `src/shared/hooks/` | `useFocusTrap` · `useCountdown` · `useScrollShadow` (سلوك النموذج الثابت مُعاد تأليفه) · `useStepGate` (قاعدة النماذج متعددة الخطوات `CS-051`) |
| `tests/support/` | `a11y.ts` (التأكيدات الثلاث لكل شاشة) · `integrationProbe.ts` (حساب الفحص + توكن API) |
| `tests/warmup.setup.ts` | يدفع كلفة أول تصريف لـVite قبل أن يبدأ عدّاد أي اختبار |
| `tests/{unit,e2e,visual,a11y,integration}/` | فارغة بـ`.gitkeep` — مواضع الاختبارات الأربعة لـPlaywright والخامس لـVitest |

**ما استُبعد عمدًا:** الشاشات · الموديولات · `src/styles/*` والتوكنز · `src/app/*` (الموجّه والتخطيط) · `fixtures` · `src/shared/components/*` · `src/shared/seo/*` (يقرأ نقطة API خاصة بموديول البحث) · `src/shared/format/dateTime.ts` (يثبّت منطقة عرض بعينها) · `useResultsScroll` (يعتمد على صنف CSS من نظام التصميم) · `profilePhotoSignal` (إشارة خاصة بشاشة). كل هذا يُبنى لكل مشروع من نموذجه الثابت المعتمد.

## قاعدة سجل المسارات — اقرأها قبل أول شاشة

**المسارات تُنسخ حرفيًّا من خريطة التنقل المعتمدة ولا تُشتق.** كل `path` في الكود يقابله صفٌّ في سجل المسارات (`docs/02-design/admin/global-navigation-map.md` لبوابة الإدارة · `docs/00-product/global-navigation-map.md` لتطبيق العملاء)، ويحمل معرّف الصفّ (`RT-*`) في تعليق بجواره. الاشتقاق من ملفات HTML مرفوض، والصفوف `PROVISIONAL` لا يُبنى عليها كود.

**والملف يُسمّى `routes.tsx` (أو `routes.ts`) حصرًا.** بوابة المسارات (`scripts/route-check.sh`) تجمع ملفات المسارات **بالاسم**؛ ملفٌ يعرّف مسارات باسم آخر (`adminRoutes.tsx` · `router.tsx` · `paths.ts`) **غير مرئي للبوابة** — تمرّ خضراء على مسارات لم تفحصها. المشروع المرجعي رصد ذلك وأضاف إلى البوابة فحصًا يرفض أي ملف يحوي `path:` باسم غير مجموع، لكن القاعدة الأولى هي التسمية.

```text
src/app/routes.tsx                       ← مسارات النظام (خطأ 401/403/404/500 · الجذر)
src/modules/<module-kebab>/routes.tsx    ← مسارات الموديول
```

## القيود الثلاثة في Playwright — تعلّمناها بالخسارة

1. **Chromium من حزمة توزيعة Alpine لا من Playwright.** حزمة Playwright مبنيّة على glibc وتُثبَّت على Alpine ثم لا تُقلع. `docker/node/Dockerfile` يثبّت `chromium` و`playwright.config.ts` يسمّيه صراحةً بـ`PLAYWRIGHT_CHROMIUM_PATH`. النتيجة: محرّك العرض هو ما تشحنه الحزمة، فخطوط الأساس تُولَّد **داخل الحاوية حصرًا**، وإعادة بناء الصورة على Alpine أحدث قد تحرّك العرض وتستلزم إعادة توليدها — فرقٌ مرئي قابل للمراجعة لا صامت.
2. **خطوط `ttf-dejavu` شرط صحة لا زينة.** بدونها يصير كل حرف عربي مربّعًا، فتقارن بوابة المطابقة البصرية خطوط أساس لصفحة غير مقروءة **وتُعلن النجاح**.
3. **`workers: 1` مثبَّت.** الحقل الغائب يشتقّه Playwright من نوى المضيف (`ceil(cores/2)`) فتُشغّل البوابة توازيًا مختلفًا على كل جهاز. وبأربعة عمّال سقط **الاختبار الأول في كل ملف** (واحد لكل عامل عند أول تنقّل متزامن): visual 14/18 · a11y 33/37. بعامل واحد 18/18 و37/37 بكلفة 36 ثانية وباختبارٍ مفرد أسرع. لا يُرفع.

## تصليب بوابة المطابقة البصرية — ثلاثة أرقام كلٌّ منها أُثبت بخرق

| الإعداد | القيمة | الثغرة التي أغلقها |
|---|---|---|
| `threshold` | `0` | افتراض Playwright `0.2` لكل بكسل أبطل العتبة: نُقل لون العلامة التجارية درجةً فأعلنت البوابة الخضرة — لم يُحسب بكسل مختلفًا أصلًا |
| `maxDiffPixelRatio` | `0.001` | «شبه صفر» كرقم؛ لكن 0.1% من 1280×800 = 1024 بكسل، والحروف العربية رفيعة: إعادة كتابة `<h1>` كاملٍ حرّكت 587 بكسل ومرّت خضراء |
| `maxDiffPixels` | `100` | سقف مطلق بجوار النسبة؛ Playwright يُفشل عند تجاوز **أيٍّ** منهما فيحكم الأصغر — أُثبت بخرق لأن قاعدة الجمع هي بالضبط صنف الافتراض الذي أنتج الثغرتين |

وخطوط الأساس **تُلتزم** في `tests/**/*-snapshots/` (مرجع خارج التحكم بالإصدار ليس مرجعًا)، ولا تُحدَّث إلا بمقارنة وتقرير وموافقة مالك المنتج.

## قواعد كتابة الواجهة

- **التكافؤ البصري 100%** مع النموذج الثابت المعتمد: الألوان والتخطيط وحالات المكوّن (`hover` · `focus` · `disabled` · `empty` · `loading` · `error`) وRTL. **إعادة تأليف لا استيراد**: تُنقل القيم والتخطيط والنصوص، ولا يُنقل `.css`/`.html`/jQuery/مكتبات النموذج.
- **لا ابتكار في التحويل:** لا مكوّن ولا حالة ولا رسالة ولا زر ولا فلتر غير موجود في التوثيق والنموذج. تحسين UX بلا Change Request ممنوع.
- **لا `fetch` في مكوّن** (`CS-044`) — كل طلب عبر `shared/api`. المسار يُنسخ حرفيًّا من `api-contracts.md` ولا يُركَّب من أجزاء (`API-005`).
- **التفريع على `error.code` لا على الرسالة** (`ECS-011`).
- **لا معرّف داخلي (`SCR-*` · `API-*` · `RT-*`) يُطبع على شاشة** — في التعليقات فقط.
- **النماذج متعددة الخطوات** عبر `useStepGate`: لا «السابق» في الخطوة الأولى، «التالي» يتحقق من حقول الخطوة ويُظهر رسائلها، والإرسال يعود لخطوة الخطأ.
- **فحص الخطوط** (موصى به كاختبار e2e): كل عائلة خط تسمّيها توكنز `--font-*` يجب أن تكون مُعلَنة بـ`@font-face` **وتُحمَّل لكل نطاق حروف** (العربي واللاتيني كلٌّ على حدة — `document.fonts.load` بلا نص يفحص اللاتيني وحده)، ولا خط من مضيف خارجي. عائلةٌ غير معلَنة تسقط بصمت إلى التالية وتظهر صفحة مقروءة بالخط الخطأ ولا يلتقطها شيء.

## الاعتماد — الخطوات

```bash
# داخل حاوية node (نفس إصدار Node الذي يستعمله CI):
docker compose exec node npm create vite@latest . -- --template react-ts
# ثم انسخ هذا المجلد فوق الناتج (يستبدل package.json و tsconfig و vite.config
# و eslint.config و index.html ويضيف playwright.config و tests/ و src/shared/)
docker compose exec node npm install
# {{PROJECT_SLUG}} في package.json · {{PROJECT_NAME}} في index.html
# TODO-GENERALIZE في sessionExpiry.ts و warmup.setup.ts و tests/support/*
```

ثم الخطوة الأولى في أي شاشة: **بناء بوابات الواجهة وإثباتها بخرق متعمَّد** قبل الاعتماد عليها (الفحص الساكن · المكوّنات · التدفقات · البصرية · الإتاحة · المسارات).
