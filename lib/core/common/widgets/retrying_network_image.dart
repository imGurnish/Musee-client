import 'dart:async';

import 'package:flutter/material.dart';

class RetryingNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final int maxAttempts;
  final Duration retryDelay;

  const RetryingNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  });

  @override
  State<RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<RetryingNetworkImage> {
  int _attempt = 0;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(covariant RetryingNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  String _urlForAttempt() {
    final parsed = Uri.tryParse(widget.url);
    if (parsed == null) {
      return widget.url;
    }

    final updatedQueryParameters = Map<String, String>.from(
      parsed.queryParameters,
    );
    updatedQueryParameters['retry'] = _attempt.toString();

    return parsed.replace(queryParameters: updatedQueryParameters).toString();
  }

  void _scheduleRetry() {
    if (_retryScheduled || _attempt + 1 >= widget.maxAttempts) {
      return;
    }

    _retryScheduled = true;
    Future<void>.delayed(widget.retryDelay, () {
      if (!mounted) return;
      setState(() {
        _attempt += 1;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return widget.fallback;
    }

    return Image.network(
      _urlForAttempt(),
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        _scheduleRetry();
        return widget.fallback;
      },
    );
  }
}
