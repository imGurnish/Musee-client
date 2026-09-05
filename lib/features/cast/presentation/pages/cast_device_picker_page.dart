import 'package:flutter/material.dart';
import 'package:musee/features/cast/presentation/widgets/cast_pairing_sheet.dart';

class CastDevicePickerPage extends StatelessWidget {
  const CastDevicePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast & Devices'),
      ),
      body: const Center(
        child: CastPairingSheet(),
      ),
    );
  }
}
