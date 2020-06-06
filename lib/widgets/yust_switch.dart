import 'package:flutter/material.dart';

class YustSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final Color activeColor;
  final void Function(bool) onChanged;

  const YustSwitch({
    Key key,
    this.label,
    this.value,
    this.activeColor,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          title: Text(label ?? '', style: TextStyle(color: Colors.grey[600])),
          trailing: Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        ),
        Divider(height: 1.0, thickness: 1.0, color: Colors.grey)
      ],
    );
  }
}
