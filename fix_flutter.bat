@echo off
echo Updating Gradle to 8.10...
powershell -Command "(gc android/gradle/wrapper/gradle-wrapper.properties) -replace 'gradle-.*-all.zip', 'gradle-8.10-all.zip' | Out-File -encoding ASCII android/gradle/wrapper/gradle-wrapper.properties"

echo Updating AGP to 8.3.2...
powershell -Command "(gc android/settings.gradle) -replace '8.1.0', '8.3.2' | Out-File -encoding ASCII android/settings.gradle"

echo Setting SDK to 36...
powershell -Command "(gc android/app/build.gradle) -replace 'compileSdk = \d+', 'compileSdk = 36' | Out-File -encoding ASCII android/app/build.gradle"
powershell -Command "(gc android/app/build.gradle) -replace 'targetSdk = \d+', 'targetSdk = 36' | Out-File -encoding ASCII android/app/build.gradle"

echo Done! Run 'flutter run' now.
pause