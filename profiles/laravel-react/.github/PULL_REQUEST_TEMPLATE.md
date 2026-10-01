<!--
  Shift SDF — Stack Profile laravel-react — PULL_REQUEST_TEMPLATE.md (v0.1.0, DRAFT)
  origin: sanam-al-ezz/.github/PULL_REQUEST_TEMPLATE.md · generalization: reviewed
  No YAML front matter here on purpose: GitHub inserts this file verbatim into
  every PR body, and a front-matter block would be inserted with it.

  هذا القالب لطلب تسليم دورة التكامل إلى main. لا تفتح مسارات الكتابة PRs
  مستقلة إلى main. كل قسم أدناه إلزامي.
-->

## 1. Task Packet

- Task ID:
- Role:
- Module:
- Objective:
- Requirements / Business Rules / Acceptance Criteria:
- Authoritative Sources:
- Dependencies:
- Allowed Paths:
- Forbidden Paths:
- Shared Files Reserved:
- Contracts:
- Branch / Worktree:
- Docker/Test Isolation:
- Escalation Conditions:

### مسارات الدورة المجمّعة

| Task ID | Module | Final reviewed SHA | Local review verdict | Targeted checks |
|---|---|---|---|---|
| | | | | |

- Integration branch: `codex/cycle-<id>-integration`
- Integration base (`main` SHA):
- Lane merge method: `--no-ff`
- Shared-file changes made by Integration Owner:
- Excluded/deferred lanes and reasons:

## 2. تقرير المنفّذ (Delivery Report)

- Commit SHA:
- Push Status:
- Files Changed:
- Requirements Covered:
- Contracts Changed:
- Migrations:
- المراجعة الذاتية (ما راجعه المنفّذ في diff نفسه قبل الرفع):
- Review Instructions (أوامر تحقق قابلة لإعادة التنفيذ):

## 3. الفحوص المنفَّذة ونتائجها

- محليًّا على البصمة النهائية (`bash scripts/quality.sh --with-tests` — عدد البوابات المفعّلة / الموقوفة كما يطبعه السكربت):
- CI push على فروع العمل: `N/A` — معطّل بقرار (CI على `main` وطلبات الدمج إليها فقط)
- CI مستقل لكل مسار إلى `main`: `N/A` — ممنوع (طلب دمج واحد من فرع التكامل)
- CI `pull_request` الواحد على مرشّح التكامل المجمّع (رقم التشغيلة · نتيجة «بوابات الجودة» · تصريح المفعّلة/الموقفة):
- خروق متعمَّدة أُثبتت بها بوابة مستحدثة (إن وُجدت):

## 4. المراجعة المستقلة وملاحظاتها

<!-- تُملأ من حزمة المراجعة المستقلة (وكيل مراجع منفصل عن جلسة التنفيذ). لا تُسجَّل كموافقة بشرية في GitHub. -->

- تاريخ المراجعة · نطاقها:
- الملاحظات الحرجة (يجب إغلاقها كلها قبل الدمج):
- الملاحظات غير الحرجة:
- الحكم: `APPROVE` / `CHANGES_REQUESTED`

## 5. بوابات القرار البشري (HG-I-*)

<!-- كل بوابة عُبرت في هذه الدورة تُذكر بمرجع اعتماد مالك المنتج قبل البناء. «لا شيء» يُكتب صراحةً. -->

| البوابة | عُبرت؟ | مرجع الاعتماد (قرار · تاريخ) |
|---|---|---|
| HG-I-01 قيمة مالية/نسبة/رسم في كود أو بذرة | | |
| HG-I-02 تحويل صف صلاحيات إلى قاعدة تفويض | | |
| HG-I-03 هجرة مُدمِّرة | | |
| HG-I-04 نقطة API خارجية أو تُصدِّر بيانات شخصية | | |
| HG-I-05 انحراف عن data-model / api-contracts | | |
| HG-I-06 بناء على عنصر PROPOSED/OPEN | | |
| HG-I-08 حذف أو نقل ملف | | |

## 6. تأكيد مالك المنتج

- [ ] قرأتُ تقرير المنفّذ والمراجعة المستقلة.
- [ ] كل ملاحظة حرجة مغلقة.
- [ ] الدمج: وفق تفويض الدمج المسجَّل في سجل القرارات — أو يدمجه المالك بنفسه.

## 7. المخاطر والأسئلة غير المحسومة

- Assumptions / Limitations / Risks:
- Unresolved Questions:

## 8. تصريح المشروع الفردي

> **لا توجد مراجعة بشرية مستقلة لهذا الـPR لأن المشروع فرديّ.** البديل المعتمد: PR موثَّق + CI كامل مانع + مراجعة ذاتية + مراجعة مستقلة قبل الدمج، وقرار الدمج لمالك المنتج أو لمن فوّضه.

## Definition of Done

- [ ] النطاق لم يتجاوز Allowed Paths.
- [ ] كل SHA لمسار مذكور ومراجع، وكل دمج إلى فرع التكامل محفوظ النسب بـ`--no-ff`.
- [ ] لا يوجد PR مستقل لأي مسار كتابي إلى `main`.
- [ ] لا تعديل غير مصرح به في وثائق التحليل المحمية أو ملف مشترك.
- [ ] كل معرّف منفذ قابل للتتبع إلى مصدر معتمد.
- [ ] فحص `بوابات الجودة` أخضر على مرشّح الدمج للبوابات المفعّلة، والموقفة معلنة ولم تُشغَّل.
- [ ] الأقسام 2–8 مكتملة والمراجعة المستقلة `APPROVE` بلا ملاحظة حرجة مفتوحة.
- [ ] الفرع حديث بالنسبة إلى `main` قبل الدمج.
