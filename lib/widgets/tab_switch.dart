import 'package:flutter/material.dart';

class TabSwitch extends InheritedWidget {
  final void Function(int) switchTo;
  const TabSwitch({super.key, required this.switchTo, required super.child});

  static TabSwitch? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabSwitch>();
  }

  @override
  bool updateShouldNotify(covariant TabSwitch oldWidget) => oldWidget.switchTo != switchTo;
}
