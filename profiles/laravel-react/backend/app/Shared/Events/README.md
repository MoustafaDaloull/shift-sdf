---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/backend/app/Shared/Events/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/backend/app/Shared/Events/ (pattern of 5 integration events)
language: ar
generalization: reviewed
---

# `app/Shared/Events/` — أحداث التكامل بين الموديولات

**القاعدة:** موديولٌ يُعلن واقعةً وآخرُ يلتقطها **لا يجوز أن يستورد أحدهما صنف الآخر** (`RS-020` · `RS-023`). فيسكن عقدُ الحدث هنا كما يسكن عقدُ الاستدعاء في `Shared/Contracts/`: السطح الثاني المسموح للعبور، وللسبب نفسه.

## متى حدثٌ ومتى عقد

| احتاج الموديول أن… | الأداة |
|---|---|
| **يسأل** موديولًا آخر ويحتاج جوابًا الآن (هل لهذا المستخدم صلاحية؟ ما حدّ الإعداد؟) | `Shared/Contracts/` — استدعاء متزامن عبر واجهة |
| **يُخبر** بأن شيئًا وقع، ولا يهمّه من يسمع ولا متى (حُقِّق حساب · نُشرت نسخة سياسة · فشلت معالجة وسائط · استُنفدت محاولات تكامل حرج) | `Shared/Events/` — حدث يُطلق، ومستمعون في موديولات أخرى |

الاتجاه حاسم: إذا كان الموديول A يقرأ من B عبر عقد، و**B** يحتاج أن يُخبر A بشيء، فالنداء المقابل من B إلى A عبر عقدٍ آخر **يُغلق دورةَ تشغيل لا يراها Deptrac** لأن طرفَيها يعبران المشترك. الحدث يكسر الدورة: B يُعلن، A يستمع.

## الشكل

```php
<?php

declare(strict_types=1);

namespace App\Shared\Events;

/**
 * <الواقعة بصيغة الماضي> — ما حدث، ولماذا يهمّ موديولًا آخر.
 *
 * يحمل المعرّف وحده؛ كل ما عداه على بُعد قراءة عقدٍ واحدة.
 */
final readonly class SomethingHappened
{
    public function __construct(
        public int $subjectId,
    ) {}
}
```

- **الاسم فعلٌ ماضٍ** يصف واقعةً لا أمرًا: `CustomerVerified` · `PolicyVersionPublished` · `MediaProcessingFailed` — لا `SendWelcomeEmail`.
- **`final readonly`** وحقول أولية. لا نموذج Eloquent في الحمولة: المستمع يقرأ ما يحتاجه من المالك عبر عقده، فيبقى الحدث صغيرًا ومستقرًّا.
- **لا منطق** ولا استيراد: `SharedEvents: ~` في `deptrac.yaml`.

## من يُطلق ومن يستمع

- **المالك** يُطلق الحدث من `Application/` عنده (`event(new SomethingHappened($id))` أو `Event::dispatch`) بعد التزام المعاملة، لا داخلها — مستمعٌ يقرأ عبر عقد قبل الالتزام يرى حالةً لم تُثبَّت.
- **المستمع** يسكن في موديول الملتقِط (`Application/Listeners/`)، ويُسجَّل في `<Module>ServiceProvider::boot()` بـ`Event::listen(SomethingHappened::class, SomeListener::class)`.
- **إذن Deptrac يُمنح يومَ يُستعمل لا قبله:** يُضاف `SharedEvents` إلى صفّ الموديول في `ruleset` مع أول حدث يُطلقه أو يلتقطه، وتُكتب العلّة في تعليق بجواره.

## ما يُسجَّل في الوثائق

كل حدث له صفٌّ في حزمة الموديول المالك (`api-contracts.md` أو ملحق الأحداث) يسمّي الحمولة والمُطلِق والملتقطين المعروفين، ومعرّفًا يُردّ إليه (`EVT-<MOD>-###` أو ما يعتمده معيار الأحداث في المشروع). كودٌ بلا معرّف مصدري = نطاق مُخترَع.
