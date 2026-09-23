# Flutter and its plugins ship their own consumer rules; keep the notification
# plugin's models so scheduled reminders survive shrinking.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
