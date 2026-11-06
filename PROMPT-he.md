<div dir="rtl">

# פסט טיווי ניל: הפרומפט

מדביקים את זה ב-Claude Code על מק שמחובר לאותו Wi-Fi כמו הטלוויזיה, או פשוט אומרים "פסט טיווי ניל"
(אם הסקיל `fast-tv-nil` מותקן). עובד על ממירים וטלוויזיות Android TV / Google TV. נבדק על ממיר Partner TV+
(Technicolor S70PCI, אנדרואיד 9). לא עובד על סמסונג Tizen, ‏LG webOS, ‏Roku או Fire TV.

מבוסס על כללי הבטיחות של `PROMPT.md` ב-[cleanyourtv](https://github.com/Gathin23/cleanyourtv) (רישיון MIT).
מסך הבית, `tools/tv.py`, `tools/theme.sh`, `tools/adb-closed.py` ו-`build-and-install.sh` באים משם.
AirPlay: [Nil5959/android-airplay-server](https://github.com/Nil5959/android-airplay-server), פורק (GPL-3.0) של
[jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server).

---

תנקה לי את ממיר האנדרואיד בכתובת `<IP>` כמו שעשינו בממיר של המרפסת. שם החדר ל-AirPlay: `<ROOM>`.
תעבוד על המכשיר האמיתי, תבדוק כל שלב עם צילום מסך מהטלוויזיה, ותעשה הכל לבד:
תשאל אותי רק על מה שצריך שלט ועל החלטות אמיתיות. תשתמש ב-`fasttv.sh` מהערכה
(https://github.com/Nil5959/fast-tv-nil) לכל שלב, ותראה את ההתקדמות במסך ההתקדמות שלה.

**לפני שמתחילים, בטלוויזיה (רק אני יכול):** הגדרות → העדפות מכשיר → מידע → ללחוץ OK על
"Build" שבע פעמים → אחורה → אפשרויות למפתחים → להדליק USB debugging (וגם Network debugging אם יש).
כשמופיע "Allow USB debugging?", לסמן "Always allow" וללחוץ Allow.

## 1. חיבור
- למצוא את הטלוויזיה: `dns-sd -B _googlecast._tcp` / `_androidtvremote2._tcp`, ואז `dns-sd -G v4 <host>.local`, או ARP.
- להתחבר ב-ADB בפורט 5555 עם `tools/tv.py` של cleanyourtv (`TV_HOST=<ip>`). במק ה-`adb` הרגיל מחזיר
  "No route to host" ברשת הביתית (הרשאת Local Network): לא לנסות לתקן, להשתמש ב-`tv.py`.
- אם זה לא אנדרואיד (אין ADB, או Tizen, webOS, Roku OS, Fire OS): לעצור ולהגיד לי.
- לבדוק `ro.build.version.sdk` (מסך הבית צריך 26 ומעלה) ו-`ro.product.cpu.abi` (ה-APK של AirPlay בנוי ל-armeabi-v7a ול-arm64-v8a).

## 2. קודם גיבוי
- לשמור `pm list packages -f / -d / -e / -3`, את `getprop`, את `settings list global|secure|system` ואת מסך הבית הנוכחי
  בתיקייה `work/backups/<ip>/`, לפני שמשנים משהו.
- לכתוב שם `restore.sh`: מדליק בחזרה כל מה שכובה, מחזיר אנימציות ל-1, מחזיר את מסך הבית הישן,
  ומציג את רשימת האפליקציות שהוסרו (מתקינים אותן מחדש מ-Play Store).

## 3. אנימציות
`window_animation_scale 0`, `transition_animation_scale 0`, `animator_duration_scale 0.5` (בהגדרות global).

## 4. כיבוי (אף פעם לא מוחקים חבילות מערכת)
- `pm disable-user --user 0`, פקודת `pm` אחת בכל קריאה, ואז לבדוק עם `pm list packages -d`:
  - `com.google.android.tvrecommendations` (המלצות של Google TV)
  - `com.google.android.leanbacklauncher.recommendations`
  - `com.google.android.katniss` (חיפוש קולי) **רק אם אף אחד לא משתמש בו**. לשאול.
  - מסך הבית המקורי (`com.google.android.tvlauncher`), **רק אחרי** שמסך הבית החדש אושר כ-Home
- אף פעם לא לכבות: שירותי הטלוויזיה והכניסות, שלט וצימוד בלוטות', המקלדת, Play Store, ‏Play Services,
  `com.android.systemui`, `com.android.shell`, `com.android.settings`, `com.android.tv.settings`, `android`,
  `com.android.providers.*`, permission controller, package installer, ext services/shared, module metadata,
  או כל דבר שאפליקציית Partner TV+ (`il.co.partnertv.atv`) צריכה. אם לא ברור מה חבילה עושה: `dumpsys package`, לא לפתוח אותה.
- לא לפתוח חבילות שבשם שלהן יש factory / fac / AT / production.
- אם `pm disable-user` נדחה לכל החבילות: לעצור ולהגיד לי.

## 5. הסרת אפליקציות שלא בשימוש
- להציג `pm list packages -3`, בלי אפליקציות המסך, מסך הבית ו-AirPlay.
- להסיר רק את מה שאף אחד לא משתמש בו (`pm uninstall --user 0 <pkg>`) ולרשום ב-`uninstalled.txt`.

## 6. מסך בית
- להתקין את מסך הבית של cleanyourtv ‏(`com.gathin.tvhome`) עם `launcher/build-and-install.sh` (`SKIP_BUILD=1` אם ה-APK כבר בנוי).
  הוא קובע אותו כ-Home ומכבה את מסך הבית המקורי רק אחרי שהחדש אושר.
  `cmd package set-home-activity` לבד לא העביר את ה-Home בממיר של פרטנר.
- לוודא עם `dumpsys activity activities | grep mFocusedApp` לפני שאומרים שזה עבד.
- לדחוף את ערכת העיצוב בסגנון Apple TV ‏(`theme-tvos/`, `tools/theme.sh`) עם `dock_apps` של הטלוויזיה הזו. במרפסת:
  Partner TV+ ‏`il.co.partnertv.atv`, נטפליקס `com.netflix.ninja`, יוטיוב `com.google.android.youtube.tv`,
  ספוטיפיי `com.spotify.tv.android`, ‏Play Store ‏`com.android.vending`; ‏`single_row`, ‏5 `columns`,
  בלי כפתורי Inputs ורשת.

## 7. AirPlay
- להתקין `airplay-receiver.apk` מ-https://github.com/Nil5959/android-airplay-server/releases/latest
  (לדחוף לטלוויזיה ואז `pm install -r`; ‏`adb install` יכול להיתקע).
- לפתוח פעם אחת (`am start -n io.github.jqssun.airplay/.MainActivity`) כדי שיעלה לבד בכל הדלקה.
- לקבוע את שם החדר:
  `am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key server_name --es value "<ROOM>"`
- כשהאייפון מתנתק, המסך של AirPlay נסגר והטלוויזיה חוזרת לאפליקציה הקודמת.

## 8. HDMI-CEC
`settings list global | grep hdmi_control`: ‏`hdmi_control_enabled` לא אמור להיות 0. במרפסת השלט של סמסונג
שולט בממיר, וכפתור ההדלקה בשלט של פרטנר מדליק את הסמסונג.

## 9. אתחול ובדיקה
- `sync`, לחכות בערך 15 שניות (אנדרואיד שומר את מצב החבילות כ-10 שניות אחרי שינוי), ואז אתחול.
- אחרי ההדלקה: ה-Home הוא מסך הבית החדש, שירות AirPlay עונה בפורט 7000 (בערך 2 דקות בממיר איטי),
  וכל מה שכובה עדיין ב-`pm list packages -d`. צילום מסך.
- נטפליקס, Live TV ו-HDMI נותנים צילום מסך ריק; במקום זה `dumpsys activity activities | grep -i ResumedActivity`.

## 10. סגירת ADB
- `settings put global adb_enabled 0`, ואז `tools/adb-closed.py <ip>` חייב להגיד שהפורט דוחה את החיבור.
  רק התשובה של הכלי הזה נחשבת.
- להזכיר לי להדליק שוב USB debugging (אפשרויות למפתחים) בפעם הבאה שצריך לשנות משהו.

## 11. סיכום
סיכום קצר לטלוויזיה הזו: דגם, מה כובה ומה הוסר, אפליקציות במסך, שם AirPlay, איפה הגיבוי ו-`restore.sh`.

</div>
