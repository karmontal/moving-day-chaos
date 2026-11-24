# النشر على Google Play

الباكج: `com.hudatalla.movingdaychaos` · المحرك يصدّر AAB من الـ preset **"Android Play"** (Gradle build،
`targetSdk 36` اللي يطلبه Play من 31 أغسطس 2026، `minSdk 24`، arm64 + armv7).
البناء: GitHub Actions ← **Google Play build** (`.github/workflows/play.yml`). نسخة itch.io (APK) ما تغيّرت.

## 1. مفتاح الرفع (مرة وحدة، على جهازك)

```bash
keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.keystore > upload.keystore.b64     # على ماك: base64 -i upload.keystore -o upload.keystore.b64
```

خلّ كلمة سر المخزن وكلمة سر المفتاح نفس الشي. احفظ `upload.keystore` وكلمة السر في مكان آمن (مو في الريبو).
بعدين في GitHub ← Settings ← Secrets and variables ← Actions ← New repository secret:

| Secret | القيمة |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | محتوى `upload.keystore.b64` |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | كلمة السر |
| `ANDROID_UPLOAD_KEY_ALIAS` | `upload` |

Play App Signing يمسك مفتاح التوقيع النهائي؛ هذا "مفتاح الرفع" بس، ولو ضاع تقدر تطلب استبداله من Play Console.

## 2. بناء الـ AAB
Actions ← Google Play build ← Run workflow (track = none) ← نزّل `moving-day-chaos-aab` من الـ artifacts.
أو ادفع تاق مثل `v0.1.0`. ملخص التشغيل يبيّن versionCode و targetSdk وهل التوقيع بمفتاح الرفع.
بدون الـ Secrets يتوقّع بالمفتاح التجريبي (يصلح للتجربة بس، Play يرفضه).

## 3. Play Console
1. حساب مطوّر ($25 مرة وحدة) + تحقق الهوية.
2. Create app: الاسم "Moving Day Chaos"، Game، Free (المجاني ما يرجع مدفوع بعدين).
3. App content: سياسة الخصوصية: https://karmontal.github.io/moving-day-chaos/privacy/ (من `site/privacy/`، تنشرها `pages.yml`؛ أول مرة: Settings ← Pages ← Source = GitHub Actions)، Ads = No،
   Data safety (تحت)، Content rating (استبيان IARC)، Target audience (13+ أسلم)، News app = No.
4. Store listing: النصوص تحت + الصور من `marketing/store/google_play/` و `marketing/store/screenshots/`.
5. Testing ← Closed testing: ارفع الـ AAB يدوي أول مرة، أضف 12 مختبِر على الأقل (إيميلات Gmail)،
   ولازم يبقون مشتركين **14 يوم متواصلة** قبل ما ينفتح لك طلب Production (للحسابات الشخصية الجديدة).
6. بعدها: Apply for production ← مراجعة جوجل (عادة أيام).

### الرفع التلقائي (اختياري، بعد أول رفع يدوي)
Google Cloud ← Service account ← JSON key، وفي Play Console ← Users and permissions ادعُ إيميل الحساب بصلاحية
Release. حط الـ JSON في Secret اسمه `PLAY_SERVICE_ACCOUNT_JSON`. بعدها Run workflow مع track = internal/alpha/…
يرفع الـ AAB كـ draft وأنت تضغط Release.

## Data safety
- Does your app collect or share any of the required user data types? **No.** التقدم والإعدادات على الجهاز بس،
  وعنوان IP في اللعب أونلاين يمر عبر سيرفر noray للاتصال وما ينحفظ (ومو من أنواع البيانات في قائمة جوجل).
  الاتصال مذكور في سياسة الخصوصية.
- لا إعلانات، لا مشتريات، لا حسابات.

## نصوص صفحة المتجر

**Title (≤30):** Moving Day Chaos · فوضى يوم النقل

**Short description (≤80)**
- EN: Co-op physics chaos: get every sofa, TV and fishbowl into the truck in time!
- AR: نقل عفش بفيزياء مجنونة مع أصحابك: دخّل الكنبة والتلفزيون للشاحنة قبل الوقت!

**Full description (EN)**
> You and your crew are movers with one job: get a whole home into the truck before time runs out.
> The sofa won't fit through the door, the TV is one bump from disaster, and your friends are "helping".
>
> • 11 moving jobs, from a tiny flat to a family house, unlocked with stars
> • Play solo or with friends: local network or online with a room code
> • Earn money for the company and buy upgrades
> • Silly physics: grab with each hand, lift together, spin, throw
> • Arabic and English
>
> No ads. No in-app purchases.

**الوصف الكامل (AR)**
> أنت وفريقك عمّال نقل عفش ومهمتكم وحدة: تنقلون بيت كامل للشاحنة قبل ما يخلص الوقت.
> الكنبة ما تبغى تطلع من الباب، والتلفزيون على وشك يطيح، وأصحابك "يساعدون".
>
> • 11 مهمة نقل من شقة صغيرة لبيت عائلة، تنفتح بالنجوم
> • العب لحالك أو مع أصحابك: شبكة محلية أو أونلاين بكود غرفة
> • اجمع فلوس للشركة واشترِ ترقيات
> • فيزياء مضحكة: امسك بكل يد، ارفعوا سوا، لف، وارمِ
> • عربي وإنجليزي
>
> بدون إعلانات وبدون مشتريات داخل اللعبة.

## الصور
| Play يطلب | الملف |
|---|---|
| App icon 512×512 | `marketing/store/google_play/icon_512.png` |
| Feature graphic 1024×500 | `marketing/store/google_play/feature_graphic_1024x500.png` |
| Phone screenshots (8) | `marketing/store/google_play/screenshots/en/` للصفحة الإنجليزية و `ar/` للعربية (1920×1080، بأزرار الجوال) |

الأيقونة والـ Feature graphic يتولدون بـ `python3 tools/make_store_assets.py`. اللقطات (لكل لغة `en` / `ar`):

```bash
for s in crew touch sofa street:winter_cabin truck town results levels; do
  SHOT_TOUCH=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
    res://tools/screenshot.tscn -- "$s" out_${s%%:*}.png ar
done
```
