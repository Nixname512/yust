import 'package:flutter/material.dart';

import '../yust.dart';

typedef DateTimeCallback = void Function(DateTime);

class YustDatePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateTimeCallback onChanged;
  final bool hideClearButton;

  YustDatePicker({
    Key key,
    this.label,
    this.value,
    this.onChanged,
    this.hideClearButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateText = Yust.service.formatDate(value);
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(label, style: TextStyle(color: Colors.grey[600])),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(dateText),
              _buildClearDate(context),
            ],
          ),
          onTap: () => _pickDate(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        ),
        Divider(height: 1.0, color: Colors.grey[800]),
      ],
    );
  }

  Widget _buildClearDate(BuildContext context) {
    if (value == null || hideClearButton) {
      return SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(Icons.clear),
      onPressed: () {
        onChanged(null);
      },
    );
  }

  void _pickDate(BuildContext context) async {
    final initDate = value ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2018),
      lastDate: DateTime(2030),
      locale: Locale('de', 'DE'),
    );
    if (selectedDate != null) {
      onChanged(selectedDate);
    }
  }
}
