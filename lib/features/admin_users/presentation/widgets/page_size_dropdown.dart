import 'package:flutter/material.dart';

class PageSizeDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const PageSizeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Page size',
        prefixIcon: Icon(Icons.tune),
      ),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: const [10, 20, 50, 100]
          .map((e) => DropdownMenuItem(value: e, child: Text('$e / page')))
          .toList(),
    );
  }
}
