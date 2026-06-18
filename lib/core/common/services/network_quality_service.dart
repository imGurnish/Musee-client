/// Estimates the appropriate streaming bitrate for "Auto" quality.
///
/// media_kit (libmpv) cannot perform true HLS adaptive-bitrate switching — once
/// it opens a master playlist it locks onto a single variant for the whole
/// track. So "Auto" is implemented in the app: for each track we pick a concrete
/// variant based on (a) the active connection type and (b) a rolling estimate of
/// recently observed download throughput. This keeps Auto genuinely responsive
/// to network conditions instead of always playing the highest variant.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NetworkQualityService {
  NetworkQualityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityResult _type = ConnectivityResult.wifi;

  /// Exponentially weighted moving average of observed throughput, in kbps.
  /// Null until the first qualifying sample is reported.
  double? _ewmaKbps;

  // Recent samples decay toward the latest observation.
  static const double _ewmaAlpha = 0.4;
  // Ignore tiny transfers; they're dominated by latency, not bandwidth, and
  // would skew the estimate downward.
  static const int _minSampleBytes = 64 * 1024;
  // Require this much headroom over a variant's nominal bitrate before we trust
  // the link to sustain it (covers per-segment bursts and HLS/TLS overhead).
  static const double _headroom = 1.6;

  /// Latest connection type (wifi/ethernet/mobile/none/...).
  ConnectivityResult get connectionType => _type;

  /// Latest throughput estimate in kbps, or null if not yet measured.
  double? get estimatedKbps => _ewmaKbps;

  void _init() {
    unawaited(_refreshType());
    try {
      _sub = _connectivity.onConnectivityChanged.listen(
        (results) => _type = _primary(results),
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _refreshType() async {
    try {
      _type = _primary(await _connectivity.checkConnectivity());
    } catch (_) {}
  }

  ConnectivityResult _primary(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    // Prefer the "best" interface when several are reported at once.
    const priority = [
      ConnectivityResult.ethernet,
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.vpn,
      ConnectivityResult.other,
    ];
    for (final p in priority) {
      if (results.contains(p)) return p;
    }
    return results.first;
  }

  /// Feed a throughput observation from a completed network transfer.
  void reportSample({required int bytes, required Duration elapsed}) {
    if (bytes < _minSampleBytes) return;
    final ms = elapsed.inMilliseconds;
    if (ms <= 0) return;
    final kbps = (bytes * 8) / ms; // bits / millisecond == kbit/s
    if (kbps <= 0 || kbps.isNaN || kbps.isInfinite) return;

    final prev = _ewmaKbps;
    _ewmaKbps =
        prev == null ? kbps : (_ewmaAlpha * kbps + (1 - _ewmaAlpha) * prev);

    if (kDebugMode) {
      debugPrint(
        '[NetworkQuality] sample=${kbps.toStringAsFixed(0)}kbps '
        'ewma=${_ewmaKbps!.toStringAsFixed(0)}kbps type=$_type',
      );
    }
  }

  /// Pick the best available variant bitrate for the current network.
  /// [available] is the list of variant bitrates (e.g. [96, 160, 320]).
  int recommendedBitrate(List<int> available) {
    if (available.isEmpty) return 160;
    final sorted = [...available]..sort();

    // 1. Measured throughput is the most accurate signal: choose the highest
    //    variant the link can comfortably sustain.
    final ewma = _ewmaKbps;
    if (ewma != null) {
      var chosen = sorted.first;
      for (final br in sorted) {
        if (ewma >= br * _headroom) chosen = br;
      }
      return chosen;
    }

    // 2. No measurement yet — fall back to a connection-type heuristic.
    switch (_type) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return sorted.last; // best
      case ConnectivityResult.mobile:
        // Middle tier on cellular until we have a real measurement.
        return sorted.length >= 2 ? sorted[sorted.length - 2] : sorted.last;
      case ConnectivityResult.none:
        return sorted.first; // worst (likely offline cache anyway)
      default:
        return sorted.length >= 2 ? sorted[sorted.length - 2] : sorted.last;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

/// Dio interceptor that turns every sizeable response into a throughput sample
/// for [NetworkQualityService]. This captures real HLS segment / playlist
/// downloads performed during background caching, giving Auto an accurate,
/// continuously-updated bandwidth estimate.
class NetworkQualityInterceptor extends Interceptor {
  NetworkQualityInterceptor(this._service);

  final NetworkQualityService _service;
  static const _startKey = '__nq_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(
      response.requestOptions,
      response.headers.value(Headers.contentLengthHeader),
    );
    handler.next(response);
  }

  void _record(RequestOptions options, String? contentLengthHeader) {
    try {
      final start = options.extra[_startKey];
      if (start is! DateTime) return;
      final bytes = int.tryParse(contentLengthHeader ?? '');
      if (bytes == null) return;
      _service.reportSample(
        bytes: bytes,
        elapsed: DateTime.now().difference(start),
      );
    } catch (_) {}
  }
}
