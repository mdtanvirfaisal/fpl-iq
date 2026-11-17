import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/home/main_navigation_shell.dart';

void main() {
  runApp(const FplIqApp());
}

class FplIqApp extends StatelessWidget {
  const FplIqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPL IQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}
