This folder is used by the app's pubspec.yaml as an assets directory.

Add your icon files here (PNG/SVG) used by the app's UI. Example names:
- cluster_icon.png
- app_logo.png

If you want launcher icons to be replaced, update the Android drawable/mipmap resources under `android/app/src/main/res` and the iOS assets in `ios/Runner/Assets.xcassets`.

After adding files, run:

flutter pub get
flutter build apk (or flutter run)
