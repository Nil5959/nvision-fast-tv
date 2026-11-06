# Partner TV+ box notes (Technicolor S70PCI)

Learned on a real box, 2026-11-06.

- Technicolor **S70PCI** ("Batman"), Marvell/Synaptics Berlin SoC, **armeabi-v7a only**, Android TV **9** (SDK 28),
  ~1.4 GB RAM. Stock home `com.google.android.tvlauncher`; Partner app `il.co.partnertv.atv`;
  Partner keyboard `com.sharkfood.partner.tv.keyboard/.LeanbackIMS` (keep it).
- Turn on ADB: Settings → System (מערכת) → About (מידע) → "Android TV OS build" × 7 → back → Developer options →
  USB debugging on. The box then listens on TCP 5555 (no Wireless debugging needed). Accept "Allow" with "Always allow".
- Biggest felt speed-up: animations 0 / 0 / 0.5. Disabling `tvrecommendations` (~20 MB), `katniss` (~50 MB, kills voice
  search) and the stock launcher (~70 MB) took MemAvailable from ~590 MB to ~680 MB after a reboot.
- Keep: everything `com.technicolor.*`, `com.marvell.*`, `com.synaptics.*`, `com.sharkfood.*`, `com.vayosoft.*`
  (Partner management), gms/gsf, WebView, `com.android.providers.tv`, Play Store, partnersetup, tv.settings, systemui,
  Bluetooth, keyboards, `com.google.android.apps.mediashell` (Cast), `com.google.android.tv.remote.service`
  (phone as a remote).
- Tiles hidden in the theme: Settings, Technicolor RemoteControlService, Marvell overscan, Partner diagnostics.
- HDMI-CEC is on by default (`hdmi_control_enabled`, `_auto_wakeup_enabled`, `_auto_device_off_enabled` = 1):
  the TV remote's keys reach the box, and waking the box turns the TV on straight to it. On a Samsung also turn off
  "Start with Smart Hub Home" (Settings → General & Privacy → Start Screen Options) and turn on Anynet+.
- N Vision AirPlay came up ~93 s after `boot_completed` (slow boot-broadcast queue). It idles at 0% CPU, ~29 MB.
- Two routers = two subnets = no AirPlay. Fix: the second router as an access point (DHCP off, uplink cable in a LAN port).
