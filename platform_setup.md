# Platform Setup for flutter_local_notifications

After running `flutter create --project-name frontend30 .` to generate platform
directories, apply the following changes before running on device/emulator.

---

## Android — `android/app/src/main/AndroidManifest.xml`

Inside `<manifest>` (before `<application>`):

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<!-- Required for exact alarm scheduling on Android 12+ -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```

Inside `<application>`:

```xml
<!-- flutter_local_notifications receivers -->
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <category android:name="android.intent.category.DEFAULT"/>
    </intent-filter>
</receiver>
```

---

## iOS — `ios/Runner/AppDelegate.swift`

No changes needed — `flutter_local_notifications` handles iOS permissions
at runtime via `NotificationService.requestPermission()`.

---

## Notification icon (Android)

Place a white-on-transparent 24 dp PNG at:

```
android/app/src/main/res/drawable/ic_notification.png
```

Then update `NotificationService._androidDetails` to use
`'@drawable/ic_notification'` instead of `'@mipmap/ic_launcher'`.
