<?php

declare(strict_types=1);

/*
 * =============================================================================
 * AS-034 — عتبات التغطية
 * -----------------------------------------------------------------------------
 * يقرأ تقرير Clover الذي تُنتجه مرحلة الاختبارات ويُقيس التغطية **بالنطاق** لا
 * إجماليًا وحده. السبب أن `--min` في PHPUnit يفحص الإجمالي فقط، والإجمالي يخدع:
 * مشروعٌ نصفه نماذج بلا منطق وربعه هجرات يبلغ 90% وهو لم يمسّ خدمة واحدة.
 * والعتبات في `AS-034` مُفرَّقة عمدًا لهذا: منطق الأعمال حيث تعيش `BR-*` له
 * عتبة أعلى، والموديولات المالية أعلى منها لأن الخطأ فيها خسارة مال.
 *
 * **النطاق غير الموجود يُعلَن `N/A` ولا يُحسب نجاحًا.** بوابة تمرّ لأن ما تفحصه
 * غير موجود تُعطي شعورًا كاذبًا بالتغطية، وهو ما يمنعه `AS-002`.
 *
 * العتبات تُقرأ من البيئة — تُمرّرها `quality.sh` من `scripts/config/shift.env`
 * لأن `scripts/` غير مربوط داخل الحاوية. الافتراضيات هنا هي افتراضيات الإطار:
 *   COVERAGE_GENERAL_MIN=70 · COVERAGE_SERVICES_MIN=85 · COVERAGE_FINANCIAL_MIN=90
 *   COVERAGE_FINANCIAL_MODULES="" (مجلدات كود مفصولة بـ| — فارغة ⟵ N/A)
 *   COVERAGE_FRONTEND_MIN=60
 *
 * الاستخدام (من داخل حاوية فيها php):
 *     php -- <clover.xml> < scripts/coverage-check.php
 * =============================================================================
 */

$path = $argv[1] ?? '';

if ($path === '' || ! is_file($path)) {
    fwrite(STDERR, "  تقرير التغطية غير موجود: {$path}\n");
    fwrite(STDERR, "  مرحلة الاختبارات هي التي تُنتجه — شغّلها أولًا.\n");
    exit(2);
}

$xml = @simplexml_load_file($path);

if ($xml === false) {
    fwrite(STDERR, "  تقرير التغطية غير قابل للقراءة: {$path}\n");
    exit(2);
}

/**
 * عتبة من البيئة أو افتراضي الإطار. قيمة غير رقمية خطأُ إعدادٍ لا يمرّ صامتًا.
 */
$threshold = static function (string $key, float $default): float {
    $raw = getenv($key);

    if ($raw === false || $raw === '') {
        return $default;
    }

    if (! is_numeric($raw)) {
        fwrite(STDERR, "  {$key} ليست رقمًا: «{$raw}» — صحّح shift.env\n");
        exit(2);
    }

    return (float) $raw;
};

$financialModules = (string) (getenv('COVERAGE_FINANCIAL_MODULES') ?: '');
$financialPattern = $financialModules === ''
    ? null
    : '#/Modules/(' . $financialModules . ')/#';

/**
 * النطاقات وعتباتها — منقولة عن `AS-034`، والقيم من الإعداد.
 * `match` دالة تقرّر انتماء الملف للنطاق من مساره.
 */
$scopes = [
    'منطق الأعمال (Application/Services)' => [
        'threshold' => $threshold('COVERAGE_SERVICES_MIN', 85.0),
        'match' => static fn (string $f): bool => str_contains($f, '/Application/Services/'),
    ],
    'الموديولات المالية (' . ($financialModules === '' ? 'غير مُعدَّة' : $financialModules) . ')' => [
        'threshold' => $threshold('COVERAGE_FINANCIAL_MIN', 90.0),
        'match' => static fn (string $f): bool => $financialPattern !== null
            && (bool) preg_match($financialPattern, $f),
    ],
    'عام' => [
        'threshold' => $threshold('COVERAGE_GENERAL_MIN', 70.0),
        'match' => static fn (string $f): bool => true,
    ],
];

$totals = [];

foreach ($scopes as $name => $_) {
    $totals[$name] = ['statements' => 0, 'covered' => 0, 'files' => 0];
}

foreach ($xml->xpath('//file') ?: [] as $file) {
    $name = (string) $file['name'];
    $metrics = $file->metrics;

    if ($metrics === null) {
        continue;
    }

    $statements = (int) $metrics['statements'];
    $covered = (int) $metrics['coveredstatements'];

    if ($statements === 0) {
        continue;   // ملف بلا عبارات قابلة للتنفيذ — واجهة أو تعداد بحت
    }

    foreach ($scopes as $scopeName => $scope) {
        if (($scope['match'])($name)) {
            $totals[$scopeName]['statements'] += $statements;
            $totals[$scopeName]['covered'] += $covered;
            $totals[$scopeName]['files']++;
        }
    }
}

$failed = 0;

printf("\n%s\n", 'عتبات التغطية — AS-034');
printf("%s\n", str_repeat('─', 60));

foreach ($scopes as $name => $scope) {
    $t = $totals[$name];
    $thr = $scope['threshold'];

    if ($t['files'] === 0) {
        printf("  \033[33m—\033[0m  %-38s N/A (لا ملف في النطاق · العتبة %.0f%%)\n", $name, $thr);

        continue;
    }

    $pct = $t['statements'] > 0 ? ($t['covered'] / $t['statements']) * 100 : 0.0;

    if ($pct + 0.005 < $thr) {
        $failed++;
        printf(
            "  \033[31m✗\033[0m  %-38s %5.1f%% < %.0f%%  (%d ملفًا)\n",
            $name,
            $pct,
            $thr,
            $t['files']
        );

        continue;
    }

    printf(
        "  \033[32m✓\033[0m  %-38s %5.1f%% ≥ %.0f%%  (%d ملفًا)\n",
        $name,
        $pct,
        $thr,
        $t['files']
    );
}

// الواجهة نطاقٌ غيرُ مقيس ما لم تُوصَل أداةُ تغطيةٍ بـVitest (`@vitest/coverage-v8`
// وسكربت `coverage` في `package.json`). يُعلَن هنا كي لا يُقرأ غيابه نجاحًا.
printf(
    "  \033[33m—\033[0m  %-38s N/A (لا أداةَ تغطيةٍ موصولةٌ بـVitest · العتبة %.0f%%)\n",
    'الواجهة',
    $threshold('COVERAGE_FRONTEND_MIN', 60.0)
);

printf("%s\n", str_repeat('─', 60));

if ($failed > 0) {
    printf("\033[31mسقط %d نطاق دون عتبته\033[0m\n", $failed);
    printf("العتبة لا تُخفَّض لتمرير بناء — خفضها قرار هندسي مُسجَّل (AS-034).\n");
    exit(1);
}

printf("\033[32mكل النطاقات فوق عتباتها\033[0m\n");
exit(0);
