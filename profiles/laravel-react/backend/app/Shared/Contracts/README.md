---
document_type: Stack Profile
framework: Shift SDF
file: profiles/laravel-react/backend/app/Shared/Contracts/README.md
version: 0.1.0
status: DRAFT
origin: sanam-al-ezz/backend/app/Shared/Contracts/ (pattern of ~90 interfaces across 15 modules)
language: ar
generalization: reviewed
---

# `app/Shared/Contracts/` — العقود العابرة بين الموديولات

**القاعدة:** هذا المجلد هو **الطريق الوحيد** بين موديولين (`RS-020` · `RS-023`). موديول يحتاج شيئًا يملكه موديول آخر لا يستورد صنفًا منه — يستهلك واجهةً من هنا. Deptrac يُفشل البناء على أي استيراد مباشر، والفحص النصي في `scripts/arch-check.sh` يرصد `JOIN` و`FOREIGN KEY` العابرَين (`RS-021` · `RS-022`).

## الشكل

```text
app/Shared/Contracts/<OwnerModuleName>/<Capability>Interface.php   ← الواجهة
app/Shared/Contracts/<OwnerModuleName>/<Something>Verdict.php      ← DTO (readonly) إن احتاج العقد كائنًا
```

- **المجلد باسم الموديول المالك** الكامل بصيغة PascalCase (`UsersAccess` · `ReferenceSettings` · `AuditLog`)، لا باسم المستهلك.
- **الواجهة تصف قدرةً واحدة** باسم يقرأ كجملة: `PermissionCheckInterface` · `SettingsReaderInterface` · `AuditLoggerInterface` · `PaymentGatewayInterface`. واجهة «كل شيء» تُعيد التشابك من الباب الخلفي.
- **DTO لا نموذج Eloquent.** ما يعبر الحدود كائنٌ `final readonly` بحقول أولية (أو تعداد)، لا `Model` ولا `Collection` من نماذج — وإلا سرى التغيير الداخلي للمالك إلى كل مستهلك.
- **المعرّفات تعبر كأعداد/نصوص**، والمفتاح الأجنبي العابر ممنوع في المخطط (`RS-022`): `user_id` في جدول موديول آخر **إشارة منطقية** بلا قيد.

## من يكتب ومن يربط

| الدور | الموديول | ما يفعله |
|---|---|---|
| **المالك** | الذي يملك الوظيفة (مثلًا الهوية ⟵ موديول المستخدمين) | يكتب الواجهة والـDTO هنا، وينفّذها داخل `Application/` عنده، **ويربط** الواجهة بالتنفيذ في `<Module>ServiceProvider::register()` (`bind` أو `singleton`) |
| **المستهلك** | أي موديول آخر | يحقن الواجهة في مُنشئ خدمته ويستعملها؛ لا يعرف اسم الصنف المنفِّذ ولا جدوله |

```php
// المالك — app/Modules/UsersAccess/UsersAccessServiceProvider.php
$this->app->singleton(PermissionCheckInterface::class, PermissionCheck::class);

// المستهلك — app/Modules/Example/Application/Services/SomethingService.php
public function __construct(private readonly PermissionCheckInterface $permissions) {}
```

## متى يُستحدث عقد

- **يومَ يُستعمل لا قبله.** عقدٌ منشور بلا مستهلك هو واجهة تُصان بلا سبب، وإذنُ Deptrac له يُخفي يومَ استُعمل فعلًا.
- **بـChange Request** إن غيّر عقدًا قائمًا له مستهلكون: العقود المشتركة من فئة «Integration Owner Only» — تُعدَّل **تسلسليًّا** قبل أي عمل متوازٍ يعتمد عليها، لا داخله.
- **لا منطق أعمال في المجلد.** `SharedContracts: ~` في `deptrac.yaml` — العقد لا يستورد شيئًا؛ عقدٌ يستورد تنفيذًا يُبطل غرضه.

## ملكية الوظائف المشتركة

لكل وظيفة مشتركة موديول مالك **واحد** (الهوية والأدوار · الوسائط · المدفوعات · الإشعارات · سجل التدقيق · الإعدادات المرجعية · التكاملات). تعديلُ وظيفة مشتركة من موديول مستهلك **ممنوع**: يُفتح Change Request ويُحدَّث المالك أولًا. مثال قائم في المشروع المرجعي: مسجّل التدقيق **لا يعتمد على** نموذج المستخدم — يكتب معرّفه كعدد، وبوابة الحدود تُفشل البناء إن اعتمد.
