<div dir="rtl">

# N Vision Fast TV: הפרומפט (בשביל ה-AI)

האדם שאתה עוזר לו רוצה שהטלוויזיה או הממיר שלו (Android TV / Google TV / Partner TV+) יוגדרו ככה:
מהירים יותר, בלי תוספות מיותרות, עם מסך בית של N Vision שיש בו רק את האפליקציות שלו,
ועם N Vision AirPlay כדי שאייפון יוכל לשדר אליהם. **הוא לא אמור לדבר איתך בצ'אט:**
כל מה שהוא צריך לעשות או לבחור קורה במסך ההתקדמות, ואתה קורא משם את הלחיצות שלו.
ענה בשפה שבה הוא כתב לך (עברית → `he`, אחרת `en`).

עובד על Android TV / Google TV מגרסה 8.0 (נבדק על ממיר Partner TV+, ‏Technicolor S70PCI, אנדרואיד 9).
לא מתאים לסמסונג Tizen, ‏LG webOS, ‏Roku או Fire TV: אם יש לו כזה, תגיד לו ותעצור.

קרדיטים: מסך הבית והכלים מ-[cleanyourtv](https://github.com/Gathin23/cleanyourtv) (MIT), וכללי הבטיחות כאן
לקוחים מה-`PROMPT.md` שלו. ‏AirPlay: ‏[Nil5959/nvision-airplay](https://github.com/Nil5959/nvision-airplay),
פורק (GPL-3.0) של [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server) (מבוסס UxPlay).

## 0. הכנה (בלי שאלות)
```
git clone https://github.com/Nil5959/nvision-fast-tv ~/nvision-fast-tv   # לדלג אם זו כבר התיקייה
cd ~/nvision-fast-tv
./fasttv.sh setup            # מוריד את cleanyourtv לתוך work/, מכין venv, מוריד את ה-APK של AirPlay
python3 -I progress.py init he        # או: en
python3 -I progress.py serve 8765     # ברקע, להשאיר רץ
```
לפתוח לו את http://127.0.0.1:8765/: בדפדפן המובנה אם יש לך, אחרת `open` (מק) או `xdg-open` (לינוקס).
להגיד לו במשפט אחד שמכאן הכל ממשיך בדף הזה.
בניית מסך הבית צריכה JDK 17 ו-Android SDK (‏`launcher/build-and-install.sh` מוצא אותם, ואומר מה חסר).

## איך הדף עובד
- `python3 -I progress.py set <step> run|ok|fail|skip "<הערה קצרה>"` לפני ואחרי כל שלב.
- `python3 -I progress.py ask <card>` מציג כרטיס (הטקסטים ב-`asks.he.json` / `asks.en.json`), ואז
  `python3 -I progress.py wait <card>` מחכה עד שהוא לוחץ על הכפתור, ומדפיס את התשובה כ-JSON
  (יציאה 3 = עדיין מחכה אחרי 9 דקות: פשוט לקרוא שוב ל-`wait`. אף פעם לא לשאול בצ'אט במקום).
- רשימות ממלאים בזמן השאלה: `progress.py ask tv '{"options":{"ip":[...]}}'`.
- `python3 -I progress.py clear` מוריד כרטיס שכבר לא צריך (למשל, הטלוויזיה כבר אישרה).
- `fasttv.sh` כבר מעדכן את הדף ושולח אליו צילומי מסך מהטלוויזיה. תסתכל בעצמך על כל צילום.

## 1. אותה רשת: כרטיס `wifi`
`set wifi run`, `ask wifi`, `wait wifi`, `set wifi ok`.

## 2. איזו טלוויזיה: כרטיס `tv`
`python3 -I find_tvs.py` (משתמש ב-`dns-sd` של מק, כ-30 שניות) נותן את האפשרויות. לשאול `tv` עם האפשרויות ולחכות.
התשובה היא `{"ip": ..., "manual": ...}`: אם `manual` מלא משתמשים בו, אחרת ב-`ip`.
אם לא נמצא כלום, לשאול `tv` בלי אפשרויות, והוא יכתוב את הכתובת (בטלוויזיה: הגדרות → רשת → החיבור).

## 3. הדלקת ADB: כרטיסים `adb` ואז `allow`
- אם פורט 5555 בטלוויזיה סגור: `set adb run`, `ask adb`, `wait adb`. אחר כך לבדוק את הפורט כל 5 שניות.
  אם אחרי 2 דקות הוא עדיין סגור, להציג שוב את `adb`.
- כשהפורט פתוח: `ask allow`, ולהריץ את `./fasttv.sh <ip> "" connect` בלולאה עד שהוא מתחבר
  (הוא מחכה להודעת "Allow" בטלוויזיה). אחר כך `clear` ו-`set adb ok`.
- במק, ה-`adb` הרגיל מחזיר "No route to host" ברשת הביתית (הרשאת Local Network). לא לנסות לתקן:
  כאן הכל עובד עם `tools/tv.py` של cleanyourtv (`TV_HOST=<ip>`).
- אם זה לא אנדרואיד (אין ADB בכלל, או Tizen, ‏webOS, ‏Roku OS, ‏Fire OS): `set connect fail` עם הסבר, להגיד לו, ולעצור.

## 4. בחירות: כרטיס `choices`
לפני השאלה אפשר להוסיף לאפשרויות של `apps` אפליקציות שמותקנות בטלוויזיה
(`pm list packages -3`, ובנוסף Netflix / YouTube / Play Store אם הן קיימות), ולהשאיר את ברירות המחדל מסומנות.
התשובה: `room` (השם ב-AirPlay; ריק → השם של הטלוויזיה עצמה), `apps` (המסך, לפי הסדר), `voice` (‏`on`/`off`),
`password` (ריק = בלי). `set choices ok "<room> · N אפליקציות"`.

## 5. העבודה (כל שורה היא פקודה אחת; אם נכשל, לקרוא את ההערה, לתקן, ולהריץ שוב רק את השלב הזה)
```
export DOCK="<אפליקציות, מופרדות ברווח>" VOICE=<on|off> PASSWORD="<סיסמה או ריק>"
./fasttv.sh <ip> "<room>" backup      # חבילות, הגדרות, getprop → work/backups/<ip>/ + restore.sh
./fasttv.sh <ip> "<room>" anim        # window 0, transition 0, animator 0.5
./fasttv.sh <ip> "<room>" disable     # המלצות Google TV / leanback; ‏katniss (קול) רק אם VOICE=off
./fasttv.sh <ip> "<room>" apps        # אפליקציות שהמשתמש התקין ולא במסך → uninstall-options.json
```
כרטיס `uninstall`: ‏`progress.py ask uninstall "{\"options\":{\"remove\":$(cat work/backups/<ip>/uninstall-options.json)}}"`,
ולחכות. אם התשובה `"skip"` → `set uninstall skip`; אחרת `./fasttv.sh <ip> "<room>" uninstall <החבילות המסומנות>`.
```
./fasttv.sh <ip> "<room>" launcher   # מסך הבית של cleanyourtv + ערכת N Vision עם DOCK; מסך הבית המקורי נכבה רק אחרי שהחדש אושר
./fasttv.sh <ip> "<room>" airplay    # ‏N Vision AirPlay, נפתח פעם אחת (כדי שיעלה בהדלקה), שם חדר, סיסמה
./fasttv.sh <ip> "<room>" cec        # מדפיס hdmi_control_*; נכשל אם HDMI-CEC כבוי
```
אחר כך כרטיס `cec` (התפריטים בצד הטלוויזיה, כמו אפשרויות מסך פתיחה בסמסונג): לשאול ולחכות (`skip` זה בסדר).
```
./fasttv.sh <ip> "<room>" verify     # sync, ‏15 שניות, אתחול; Home, ‏AirPlay בפורט 7000 (עד כ-2 דקות), ומה שכובה נשאר כבוי
```

## 6. סיום: כרטיס `finish`
ברירת המחדל היא **להשאיר את ADB פתוח**. רק אם הוא בחר `close`: ‏`./fasttv.sh <ip> "<room>" close`
(מכבה ADB, ואז `tools/adb-closed.py` חייב להגיד שהפורט דוחה חיבור). אחרת `set close ok "ADB נשאר פתוח"`.
ואז סיכום קצר בצ'אט: דגם, מה כובה ומה הוסר, המסך, שם AirPlay, איפה הגיבוי ו-`restore.sh`.
יש עוד טלוויזיות? מתחילים שוב משלב 2, טלוויזיה אחת בכל פעם.

## כללי בטיחות (מ-cleanyourtv, לשמור עליהם)
- גיבוי לפני כל שינוי. מכבים עם `pm disable-user --user 0`; אף פעם לא מוחקים חבילות מערכת.
- פקודת `pm` אחת בכל קריאה; בודקים עם `pm list packages -d`, לא לפי קוד היציאה.
- אף פעם לא לכבות: שירותי טלוויזיה וכניסות, שלט וצימוד בלוטות', מקלדות, ‏Play Store, ‏Play Services,
  `com.android.systemui`, ‏`.shell`, ‏`.settings`, ‏`com.android.tv.settings`, ‏`android`, ‏`com.android.providers.*`,
  permission controller, ‏package installer, ‏ext services / shared, ‏module metadata, ‏WebView, ‏Cast
  (`com.google.android.apps.mediashell`) אלא אם ביקשו, ובממירי פרטנר כל `com.technicolor.*`, ‏`com.marvell.*`,
  `com.synaptics.*`, ‏`com.sharkfood.*`, ‏`com.vayosoft.*`, או מה ש-`il.co.partnertv.atv` צריך.
  לא בטוח מה חבילה עושה? `dumpsys package <pkg>`, אף פעם לא לפתוח אותה. לא לפתוח חבילות factory / fac / AT / production.
- לכבות את מסך הבית המקורי רק אחרי שהחדש אושר כ-Home (‏`build-and-install.sh` עושה את זה, עם חזרה אחורה אם צריך).
  `cmd package set-home-activity` לבד לא העביר את ה-Home בממיר של פרטנר.
- לפני אתחול: `sync` ולחכות כ-15 שניות, אחרת חבילות שכובו ייראו כאילו חזרו.
- `adb install` יכול להיתקע: דוחפים את ה-APK ומריצים `pm install -r` (הסקריפטים עושים את זה).
- נטפליקס, Live TV ו-HDMI נותנים צילום מסך שחור. צילום שחור יכול להיות גם ממיר שנכנס לשינה
  (`dumpsys power | grep mWakefulness`). לבדוק `dumpsys activity activities | grep -i ResumedActivity`.
- ה-shell לא יכול לכבות פעילות אחת (`pm disable pkg/Activity`); מסתירים אריחים עם `hidden_apps` בערכה.
- AirPlay עובד רק כשהאייפון והטלוויזיה באותה רשת (ראוטר אחד, או ראוטר שני שמוגדר כנקודת גישה).
- עוד הערות על המכשיר: `docs/partner-tv-plus.md`.

</div>
