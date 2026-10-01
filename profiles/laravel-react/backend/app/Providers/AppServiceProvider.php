<?php

declare(strict_types=1);

namespace App\Providers;

use App\Shared\Support\TraceContext;
use Dedoc\Scramble\Scramble;
use Dedoc\Scramble\Support\Generator\OpenApi;
use Dedoc\Scramble\Support\Generator\Server;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // `scoped` لا `singleton`: معرّف التتبع خاصّ بطلب واحد (`API-021`).
        // ولو ثُبِّت `singleton` لعمل صحيحًا تحت PHP-FPM — حيث تموت العملية
        // مع الطلب — ثم حمل كل طلبات العامل الواحد المعرّف نفسه لحظة تشغيل
        // Octane. و`scoped` يُعاد ضبطه بين الطلبات في الحالتين.
        $this->app->scoped(TraceContext::class);
    }

    public function boot(): void
    {
        // `backend/openapi.json` عقد مُلتزَم تُقارَن به إعادةُ التوليد في بوابة
        // OpenAPI، فلا يجوز أن يحمل حقلًا يختلف باختلاف الجهاز. ومولّد
        // Scramble يمرّر كل خادم عبر `url()` فيصير مطلقًا بـ`APP_URL`.
        //
        // الاستبدال هنا لا في `config/scramble.php` لأن ذلك المسار لا يملك
        // تخطّي `url()`. والقيمة نسبية عمدًا: مسارٌ نسبي يصف العقد بلا ادّعاء
        // خادمٍ قائم.
        Scramble::configure()->withDocumentTransformers(function (OpenApi $document): void {
            $document->servers = [Server::make('/api')];
        });
    }
}
