import 'dart:async';

/// Stub implementation — headphone detection not available on this platform.
/// Always returns false / empty stream.

Future<bool> isHeadphonesConnected() async => false;

Stream<bool> headphonesStream() => const Stream.empty();
