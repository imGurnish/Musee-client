// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'device_profile.dart';

String? getPlatformStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setPlatformStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

DeviceProfile detectPlatformDevice() {
  // 1. Check explicit query override first: ?mode=receiver / ?device=tv / ?device=car / ?receiver=1
  try {
    final uri = Uri.parse(html.window.location.href);
    final mode = uri.queryParameters['mode']?.toLowerCase();
    final deviceParam = uri.queryParameters['device']?.toLowerCase();
    final receiverParam = uri.queryParameters['receiver']?.toLowerCase();

    if (mode == 'receiver' || receiverParam == '1' || receiverParam == 'true' || deviceParam == 'tv') {
      return const DeviceProfile(
        formFactor: DeviceFormFactor.tv,
        displayName: 'Web TV Display',
        isReceiver: true,
      );
    }
    if (deviceParam == 'car') {
      return const DeviceProfile(
        formFactor: DeviceFormFactor.car,
        displayName: 'In-Car Display',
        isReceiver: true,
      );
    }
  } catch (_) {}

  // 2. Check stored preference in localStorage
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
      displayName: 'Web Browser',
      isReceiver: false,
    );
  }

  // 3. Detect via User-Agent and Screen properties
  final ua = (html.window.navigator.userAgent).toLowerCase();

  // In-Car Browsers & Automotive Systems
  if (ua.contains('tesla') ||
      ua.contains('qtcarplayer') ||
      ua.contains('model s') ||
      ua.contains('model 3') ||
      ua.contains('model x') ||
      ua.contains('model y')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.car,
      displayName: 'Tesla In-Car Browser',
      brand: 'Tesla',
      isReceiver: true,
    );
  }

  if (ua.contains('automotive') ||
      ua.contains('android auto') ||
      ua.contains('carbrowser') ||
      ua.contains('polestar') ||
      ua.contains('mbux') ||
      ua.contains('idrive') ||
      ua.contains('rivian') ||
      ua.contains('lucid') ||
      ua.contains('incar')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.car,
      displayName: 'In-Car Infotainment',
      isReceiver: true,
    );
  }

  // Smart TVs
  if (ua.contains('tizen') ||
      ua.contains('maple') ||
      ua.contains('smart-tv') ||
      ua.contains('smarttv') ||
      ua.contains('samsungbrowser') && ua.contains('tv')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Samsung Smart TV',
      brand: 'Samsung',
      isReceiver: true,
    );
  }

  if (ua.contains('webos') ||
      ua.contains('web0s') ||
      ua.contains('netcast') ||
      ua.contains('lg browser') ||
      ua.contains('lg netcast')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'LG webOS TV',
      brand: 'LG',
      isReceiver: true,
    );
  }

  if (ua.contains('aftt') ||
      ua.contains('aftm') ||
      ua.contains('afts') ||
      ua.contains('aftb') ||
      ua.contains('firetv') ||
      (ua.contains('silk/') && ua.contains('android'))) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Amazon Fire TV',
      brand: 'Amazon',
      isReceiver: true,
    );
  }

  if (ua.contains('googletv') ||
      ua.contains('google tv') ||
      ua.contains('android tv') ||
      ua.contains('bravia') ||
      ua.contains('shield android tv') ||
      ua.contains('mitv') ||
      ua.contains('crkey')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Android / Google TV',
      brand: 'Google',
      isReceiver: true,
    );
  }

  if (ua.contains('vidaa') || ua.contains('hisense')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Hisense VIDAA TV',
      brand: 'Hisense',
      isReceiver: true,
    );
  }

  if (ua.contains('viera') || ua.contains('panasonic')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Panasonic TV',
      brand: 'Panasonic',
      isReceiver: true,
    );
  }

  if (ua.contains('roku')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Roku TV',
      brand: 'Roku',
      isReceiver: true,
    );
  }

  if (ua.contains('appletv')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Apple TV',
      brand: 'Apple',
      isReceiver: true,
    );
  }

  final isGenericTv = RegExp(r'\b(?:tv|smarttv|smart-tv|googletv|appletv|hbbtv|dtv)\b').hasMatch(ua);
  if (ua.contains('hbbtv') ||
      ua.contains('philips') ||
      ua.contains('aquos') ||
      ua.contains('opera tv') ||
      ua.contains('dtv') ||
      (isGenericTv && !ua.contains('mobile') && !ua.contains('ipad') && !ua.contains('iphone'))) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tv,
      displayName: 'Smart TV Browser',
      isReceiver: true,
    );
  }

  // 4. Fallback: Phone vs Tablet vs Desktop
  if (ua.contains('mobile') || ua.contains('iphone') || (ua.contains('android') && !ua.contains('tablet'))) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.phone,
      displayName: 'Mobile Phone',
      isReceiver: false,
    );
  }

  if (ua.contains('ipad') || ua.contains('tablet')) {
    return const DeviceProfile(
      formFactor: DeviceFormFactor.tablet,
      displayName: 'Tablet',
      isReceiver: false,
    );
  }

  return const DeviceProfile(
    formFactor: DeviceFormFactor.desktop,
    displayName: 'Web Browser',
    isReceiver: false,
  );
}
