enum DeviceFormFactor {
  phone,
  tablet,
  desktop,
  tv,
  car,
}

class DeviceProfile {
  final DeviceFormFactor formFactor;
  final String displayName;
  final String? brand;
  final String? model;
  final bool isReceiver;

  const DeviceProfile({
    required this.formFactor,
    required this.displayName,
    this.brand,
    this.model,
    this.isReceiver = false,
  });

  bool get isTv => formFactor == DeviceFormFactor.tv;
  bool get isCar => formFactor == DeviceFormFactor.car;
  bool get isPhone => formFactor == DeviceFormFactor.phone;
  bool get isTablet => formFactor == DeviceFormFactor.tablet;
  bool get isDesktop => formFactor == DeviceFormFactor.desktop;
}
