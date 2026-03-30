import 'dart:io';

Future<bool> fileExists(String path) => File(path).exists();

bool get isAndroidOrIOS => Platform.isAndroid || Platform.isIOS;

bool get isAndroidPlatform => Platform.isAndroid;
