import 'device_profile.dart';

DeviceProfile detectPlatformDevice() {
  return const DeviceProfile(
    formFactor: DeviceFormFactor.desktop,
    displayName: 'Default Device',
    isReceiver: false,
  );
}

String? getPlatformStorage(String key) => null;
void setPlatformStorage(String key, String value) {}
