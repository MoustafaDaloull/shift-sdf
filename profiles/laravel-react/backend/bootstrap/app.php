<?php

use App\Shared\Exceptions\ApiExceptionRenderer;
use App\Shared\Http\ApiSurface;
use App\Shared\Http\Middleware\AssignTraceId;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        // `api.php` ملف تجميع بلا تعريف (`RS-016`) — تسجيله هنا هو ما يُنشئ
        // مجموعة الوسائط `api` وبادئة `/api`، وعليهما تتّكئ مزوّدات الموديولات.
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // `API-021` — كل استجابة تحمل `X-Trace-Id`، نجحت أو فشلت.
        //
        // **عام لا مجموعة `api`:** وسيط المجموعة لا يعمل إن لم يُطابَق مسار،
        // فكان 404 يخرج بجسمٍ فيه `trace_id` وترويسةٍ فارغة — أي أن الترويسة
        // تغيب في الحالة التي وُضعت لأجلها. التفصيل في `AssignTraceId`.
        $middleware->append(AssignTraceId::class);

        // Behind any terminating load balancer the socket peer is the
        // balancer, not the user. Without trusting it, every client shares one
        // IP, so each per-IP rate limit (OTP, login) becomes one bucket for the
        // whole platform, and `https` is lost from generated URLs.
        //
        // NOT `*`: `*` trusts EVERY address, so the client IP becomes the
        // left-most X-Forwarded-For entry, which the caller writes. Measured on
        // the reference project: a forged address landed in the audit log, and
        // it would equally have reset every per-IP rate limit. Only the hops
        // that are ours are trusted: loopback and private ranges (Compose
        // networks, an nginx sidecar) and link-local (a managed front end's
        // peer address). The client IP is then the right-most UNtrusted entry,
        // which no caller can forge. X-Forwarded-Host is deliberately NOT
        // trusted: URLs keep the real Host.
        $middleware->trustProxies(
            at: [
                '127.0.0.0/8',
                '10.0.0.0/8',
                '172.16.0.0/12',
                '192.168.0.0/16',
                '169.254.0.0/16',
                '::1',
                'fc00::/7',
                'fe80::/10',
            ],
            headers: Request::HEADER_X_FORWARDED_FOR
                | Request::HEADER_X_FORWARDED_PORT
                | Request::HEADER_X_FORWARDED_PROTO,
        );

        // Project-wide API middleware (a consent wall, a maintenance gate, ...)
        // is appended to the `api` GROUP here — not named on each route — so
        // the default is refusal and a route whose tag is forgotten is not the
        // one an unentitled user reaches:
        //   $middleware->appendToGroup('api', SomeGate::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(ApiSurface::matches(...));

        // كل خطأ في مسار API يخرج من `ApiExceptionRenderer` وحده — `ECS-003`.
        //
        // يُسجَّل هنا لا في متحكم ولا في `try/catch` متكرر، لأن `ECS-003`
        // قيدٌ على **كل** استجابة خطأ بما فيها ما يُرمى قبل بلوغ المتحكم:
        // فشل التوجيه · فشل ربط النموذج · فشل الوسيط. وما يُلتقط في المتحكم
        // وحده يترك هذه الثلاثة تخرج بشكل الإطار لا بشكل العقد.
        //
        // `Throwable` بلا `use` عن قصد: هذا الملف بلا `namespace`، فالاسم يُحلّ
        // عالميًّا أصلًا، و`use Throwable;` فيه استيرادٌ بلا أثر يُطلق تحذير
        // PHP 8.5 في **كل** استدعاء — وقد لوّث 19 اختبارًا فأسقط بوابة
        // الاختبارات قبل أن يُرصد. لا تُعِد إضافته.
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! ApiSurface::matches($request)) {
                return null;
            }

            return app(ApiExceptionRenderer::class)->render($request, $e);
        });
    })->create();
