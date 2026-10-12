---
document_type: Stack Profile Guide
framework: Shift SDF
file: profiles/laravel-react/docs/local-setup-without-docker.md
version: 0.2.0
status: DRAFT
origin: sanam-al-ezz/docs/03-development/herd-local-setup.md (2026-10-11)
language: ar
generalization: reviewed
---

# تشغيل المنصة على جهاز بلا Docker — للعرض والتجربة

**لمن هذا الملف:** من يريد تشغيل المنصة على جهازه بـPHP وMySQL وNode محليّة (Laravel Herd أو ما يماثله) — للتجربة والعرض على مالك المنتج.

**ما ليس فيه:** بيئة الإنتاج، وبوابات الجودة. **البوابات تحتاج Docker** (`bash scripts/quality.sh`) ولا تعمل على هذا الإعداد؛ فلا تُغلق شريحة ولا يُقاس شيء منه. وما يُشاهَد هنا «يعمل عندي» بالتعريف (`lessons/README.md L-004`).

---

## 1. ما تحتاجه

| الأداة | الإصدار | ملاحظة |
|---|---|---|
| PHP | ما يثبّته الملف الشخصي في صورته (`docker/php/Dockerfile`) أو أعلى | من إعدادات Herd |
| MySQL | **8.0 فأعلى** (المستهدف 8.4) | خدمة Herd Pro أو تثبيت مستقل |
| Node.js | **22 فأعلى** | للواجهة |
| Composer | 2.x | غالبًا مع Herd |
| FFmpeg | اختياري | لازم لمعالجة **الفيديو** فقط إن كان في المشروع |

**امتدادات PHP المطلوبة:** `pdo_mysql` · `intl` · `gd` · `exif` · `bcmath` · `zip` · `mbstring` · `openssl`. تحقّق بـ`php -m`.

**لا تحتاج Redis:** الإعداد أدناه يضع الذاكرة المؤقتة في الملفات والطابور في قاعدة البيانات. (الإنتاج والتطوير على Docker يبقيان على نسختَي Redis — `docker/README.md §4.5`.)

---

## 2. الخادم

```bash
cd backend
herd link {{PROJECT_SLUG}}            # العنوان: http://{{PROJECT_SLUG}}.test — جذر الموقع backend/public
```

قاعدة البيانات **بالترميز والترتيب نفسيهما** اللذين يفرضهما الملف الشخصي — ترتيبٌ مختلف يجعل اسمين مختلفين يُقرآن متطابقين في لغة ذات تشكيل:

```sql
CREATE DATABASE {{PROJECT_SLUG}} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

`backend/.env` من `.env.example` مع هذه القيم (ما عداها كما في القالب):

```ini
APP_URL=http://{{PROJECT_SLUG}}.test
DB_HOST=127.0.0.1
DB_DATABASE={{PROJECT_SLUG}}
CACHE_STORE=file
QUEUE_CONNECTION=database
SESSION_DRIVER=database
FILESYSTEM_DISK=local
```

ثم:

```bash
composer install
php artisan key:generate
php artisan migrate --seed            # البذور الحقيقية (المرجعية والمحتوى) — لا بيانات العرض
php artisan storage:link
```

**بيانات العرض** (حسابات تجريبية وسجلات مبذورة) تُبذر بأمرها الصريح إن كان للمشروع بذّار عرض، ولا تُبذر على بيئة يراها غير الفريق إلا بقرار. وحسابات الاختبار تُنشأ بسكربت لا باليد (`lessons/README.md L-049`).

**الطابور:** ما يعتمد على الطابور (إشعارات · معالجة وسائط · مهام مجدولة) لا يعمل حتى يعمل عامل:

```bash
php artisan queue:work --tries=1      # في نافذة مستقلة
php artisan schedule:work             # إن كان في المشروع مهام مجدولة
```

---

## 3. الواجهة

```bash
cd frontend
npm ci
```

`frontend/.env.local`:

```ini
VITE_API_BASE_URL=http://{{PROJECT_SLUG}}.test/api
```

ثم `npm run dev` للتطوير على `http://localhost:5173`، أو `npm run build` ثم خدمة `dist/` من Herd بموقع ثانٍ للعرض الأقرب إلى الإنتاج.

---

## 4. ما يختلف عن حزمة Docker — ويُعلَن

| البند | على Docker | هنا |
|---|---|---|
| الذاكرة المؤقتة وتحديد المعدّل | `redis-cache` | ملفات — تحديد المعدّل بالذاكرة المؤقتة في الملفات أبطأ ولا يُقاس عليه |
| الطابور والجلسات | `redis` | قاعدة البيانات |
| خدمة الويب | nginx بترويسات الأمن وCSP (`docker/nginx/snippets/`) | خادم Herd — **بلا ترويسات الأمن**؛ لا يُعرض على الإنترنت |
| البريد | Mailpit | ما تضبطه في `MAIL_MAILER` (`log` يكفي للعرض) |
| حدود الرفع | في طبقتين (`php.ini` · nginx) بالقيم نفسها | `php.ini` الخاص بـHerd وحده — ارفع `upload_max_filesize` و`post_max_size` إن احتجت (`lessons/README.md L-033`) |
| الأسرار | `.env` بقيم وهمية في القالب | نفسه — **لا سر حقيقي على جهاز عرض** |

---

## 5. مشاكل شائعة

| العرض | السبب | العلاج |
|---|---|---|
| `SQLSTATE[HY000] [2002]` | MySQL لا يعمل أو المنفذ مختلف | شغّل الخدمة أو صحّح `DB_PORT` |
| صفحة بيضاء وخطأ `intl` | امتداد `intl` غير مفعّل | فعّله من إعدادات PHP في Herd |
| الصور لا تُعرض | `storage:link` لم يُنفَّذ | `php artisan storage:link` |
| الإشعارات لا تصل | لا عامل طابور | `php artisan queue:work` |
| `SSL certificate problem` في `composer` | اعتراض TLS من مضاد الفيروسات على المضيف | `lessons/README.md L-032` |
