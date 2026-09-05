import 'device_profile.dart';
import 'device_detector_platform_stub.dart'
    if (dart.library.html) 'device_detector_platform_web.dart'
    if (dart.library.io) 'device_detector_platform_io.dart';

export 'device_profile.dart';

class DeviceDetector {
  static DeviceProfile? _cachedProfile;

  /// Full profile of current running device
  static DeviceProfile get profile {
    _cachedProfile ??= detectPlatformDevice();
    return _cachedProfile!;
  }

  /// Whether this device was identified as a TV or Car display (or user marked as receiver)
  static bool get isReceiverDefault => profile.isReceiver;

  /// Whether this device is specifically a TV
  static bool get isTv => profile.isTv;

  /// Whether this device is specifically an in-car display
  static bool get isCar => profile.isCar;

  /// Form factor (phone, tablet, desktop, tv, car)
  static DeviceFormFactor get formFactor => profile.formFactor;

  /// Human-friendly name (e.g. "Tesla In-Car Browser", "Samsung Smart TV", "Android TV", etc.)
  static String get detectedDisplayName => profile.displayName;

  /// Persist user preference: 'auto', 'receiver_tv', 'receiver_car', 'standard'
  static void setDeviceMode(String mode) {
    setPlatformStorage('musee_device_mode', mode);
    _cachedProfile = null;
  }

  /// Reset to auto detection
  static void resetToAuto() {
    setDeviceMode('auto');
  }
}
