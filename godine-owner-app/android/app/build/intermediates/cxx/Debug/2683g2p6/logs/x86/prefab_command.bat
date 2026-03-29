@echo off
"D:\\Program Files\\Android Studio\\jbr\\bin\\java" ^
  --class-path ^
  "C:\\Users\\Aditya Pandey\\.gradle\\caches\\modules-2\\files-2.1\\com.google.prefab\\cli\\2.1.0\\aa32fec809c44fa531f01dcfb739b5b3304d3050\\cli-2.1.0-all.jar" ^
  com.google.prefab.cli.AppKt ^
  --build-system ^
  cmake ^
  --platform ^
  android ^
  --abi ^
  x86 ^
  --os-version ^
  24 ^
  --stl ^
  c++_shared ^
  --ndk-version ^
  27 ^
  --output ^
  "C:\\Users\\ADITYA~1\\AppData\\Local\\Temp\\agp-prefab-staging9909369577400796803\\staged-cli-output" ^
  "C:\\Users\\Aditya Pandey\\.gradle\\caches\\9.0.0\\transforms\\eab9d5619ad36371990c02d771353060\\transformed\\react-android-0.83.2-debug\\prefab" ^
  "C:\\Users\\Aditya Pandey\\.gradle\\caches\\9.0.0\\transforms\\44cb238ccc9b1b7a5bf87029c8b55c61\\transformed\\hermes-android-0.14.1-debug\\prefab" ^
  "C:\\Users\\Aditya Pandey\\.gradle\\caches\\9.0.0\\transforms\\83198c47a1c402754cadaa99718025d1\\transformed\\fbjni-0.7.0\\prefab"
