---
document_type: Framework Checklist
framework: Shift SDF
file: checklists/project-start.md
version: 0.1.0
status: DRAFT
language: ar
---

# قائمة تحقق: بدء مشروع جديد

تُنفَّذ مرة واحدة عند إنشاء المشروع. لا تبدأ Phase 0 لأي موديول قبل اكتمالها، ويُسجَّل اكتمالها في `PROJECT-BASELINE.md §20`.

## 1. القرارات الأولى (مالك المنتج)

- [ ] اسم المشروع ومعرّفه القصير (`{{PROJECT_NAME}}` · `{{PROJECT_SLUG}}`).
- [ ] **مستوى الحوكمة:** خفيف · قياسي · كامل (`README.md §4`). يُسجَّل في الـBaseline ولا يُخفَّض إلا بقرار.
- [ ] **الحزمة التقنية:** ملف تعريف من `profiles/` أو ملف جديد. تُحسم بـADR واحد (`standards/adr/ADR-TEMPLATE.md`) ولا يُعاد تقييمها بعده.
- [ ] نموذج العمل: مالك منتج واحد ووكيل منفّذ، ومراجع مستقل (نعم/لا).
- [ ] هل الدمج مفوَّض للوكيل؟ الافتراضي **لا**. التفويض بقرار مسجَّل بشروطه الستة.
- [ ] بيئة التشغيل في هذه المرحلة: محلية حصرًا أم مع بيئة تجريبية. لا نشر بلا قرار.

## 2. المستودع

- [ ] إنشاء المستودع على GitHub، الفرع الافتراضي `main`، حماية `main` (فحص مطلوب باسم «بوابات الجودة»، لا دفع مباشر).
- [ ] نسخ `scripts/` كاملًا وملء `scripts/config/shift.env` و`modules.tsv` و`protected-paths.txt`.
- [ ] نسخ `profiles/<stack>/` إلى الجذر (`docker/` · `.github/` · `Makefile` · هياكل `backend/` و`frontend/`).
- [ ] تثبيت الخطافات: `make hooks` أو نسخ `scripts/hooks/*` إلى `.git/hooks/` يدويًا.
- [ ] `.gitignore` مفحوص: لا نمط يبتلع ملفًا مشروعًا (`lessons/README.md L-015`).
- [ ] لا سر في المستودع: `.env.example` فقط، والأسرار في مدير أسرار أو خارج المستودع.

## 3. ملفات الحوكمة في الجذر

- [ ] `CLAUDE.md` ← `governance/execution-instructions.md` (أو نسخة خفيفة مدمجة في المستوى الخفيف).
- [ ] `CLAUDE-ENGINEERING.md` ← `governance/engineering-instructions.md`.
- [ ] `CLAUDE-PHASE0.md` ← `governance/phase0-instructions.md`.
- [ ] `PROJECT-BASELINE.md` ← `governance/project-baseline-template.md`، مملوء §1 و§2 و§11 و§13 على الأقل.
- [ ] استبدال كل `{{...}}` في الملفات الأربعة. أمر الفحص: `grep -rn '{{' *.md`.

## 4. شجرة الوثائق

- [ ] `docs/00-product/`: `brd.md` · `glossary.md` · `business-rules-global.md` · `module-registry.md` · `identifier-alias-map.md` · `project-decisions.md` وفهارسه من `governance/decisions/` · `change-requests/`.
- [ ] `docs/01-modules/<module>/` لكل موديول مسجَّل، من `templates/module/`.
- [ ] `docs/02-design/`: `design-system.md` (محميّ بعد اعتماده) · خرائط التنقل · النماذج الثابتة.
- [ ] `docs/03-development/`: المعايير الـ14 من `standards/` · `architecture.md` من قالبه · `adr/` · `implementation/` من `templates/implementation/`.
- [ ] `docs/99-quality/`: بوابات التوثيق من `templates/quality-gates/` (المستوى الكامل) أو مجلد فارغ للتقارير.

## 5. سجل الموديولات والمعرّفات

- [ ] كل موديول له رقم `MOD-NN` وكود ثلاثي فريد ومجلد توثيق kebab-case ومجلد كود PascalCase وبادئة جدول.
- [ ] الصف نفسه في `module-registry.md` وفي `scripts/config/modules.tsv` وفي `identifier-alias-map.md`.
- [ ] ملكية كل وظيفة مشتركة محسومة لموديول واحد (الهوية، الوسائط، البحث، المدفوعات، الإشعارات، التدقيق، الإعدادات، المحتوى، التكاملات).

## 6. إثبات البوابات قبل أول شريحة

- [ ] الإقلاع من نسخة نظيفة: `git clone` جديد ثم `docker compose up` ثم `bash scripts/quality.sh --with-tests` أخضر.
- [ ] **كل بوابة مفعّلة أُثبتت بخرق متعمَّد** وسُجّل الدليل `EV-NNNN` في المتتبع بأمر يُعيد إنتاجه.
- [ ] البوابات غير المفعّلة في المستوى المختار مكتوبة في `SUSPENDED_GATES` وتُعلن نفسها في التشغيلة.
- [ ] CI شُغِّل مرة على `main` وعاد أخضر برقم تشغيلة.
- [ ] `QG-SYNC` أُثبتت بالتزام فارغ غير مدفوع ثم `reset --soft`.

## 7. البدء

- [ ] اختيار أول موديول من خطة الاعتماديات لا من رقمه.
- [ ] موجز Phase 0 للموديول الأول معروض على مالك المنتج قبل أي كتابة.
- [ ] تسجيل اكتمال هذه القائمة في `PROJECT-BASELINE.md §20` بتاريخ واعتماد.
