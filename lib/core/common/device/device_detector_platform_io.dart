import 'dart:io';
import 'device_profile.dart';

final Map<String, String> _memoryStorage = {};

String? getPlatformStorage(String key) => _memoryStorage[key];
void setPlatformStorage(String key, String value) => _memoryStorage[key] = value;

DeviceProfile detectPlatformDevice() {
  final storedMode = getPlatformStorage('musee_device_mode');
  if (storedMode == 'receiver_tv') {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Smart TV (Saved)',
      isReceiver: true,
    );
  } else if (storedMode == 'receiver_car') {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.car,
      displayName: 'In-Car Display (Saved)',
      isReceiver: true,
    );
  } else if (storedMode == 'standard') {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.desktop,
      displayName: 'App Mode',
      isReceiver: false,
    );
  }

  // Check Android TV / Automotive system features or environment
  if (Platform.isAndroid) {
    final env = Platform.environment;
    if (env.containsKey('ANDROID_TV') || env.containsKey('LEANBACK')) {
      return const DeviceProfile(
        formFactor: DeviceFormFactor.tv,
        displayName: 'Android TV',
        brand: 'Android',
        isReceiver: true,
      );
    }
    if (env.containsKey('ANDROID_AUTOMOTIVE') || env.containsKey('CAR_MODE')) {
      return const DeviceProfile(
        formFactor: DeviceFormFactor.car,
        displayName: 'Android Automotive',
        brand: 'Automotive',
        isReceiver: true,
      );
    }

    return const DeviceProfile(
      formFactor: DeviceFormFactor.phone,
      displayName: 'Android Device',
      isReceiver: false,
    );
  }

  if (Platform.isIOS) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.phone,
      displayName: 'iOS Device',
      isReceiver: false,
    );
  }

  if (Platform.isWindows) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.desktop,
      displayName: 'Windows PC',
      isReceiver: false,
    );
  }

  if (Platform.isMacOS) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.desktop,
      displayName: 'Mac',
      isReceiver: false,
    );
  }

  if (Platform.isLinux) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.desktop,
      displayName: 'Linux',
      isReceiver: false,
    );
  }

  return const DeviceProfile(
    formFactor: DeviceFormFactor.desktop,
    displayName: 'Desktop Device',
    isReceiver: false,
  );
}
