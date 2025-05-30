import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/screens/main_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Flame.device.fullScreen();

  runApp(MaterialApp(
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData.dark(),
    home: const MainMenu(),
  ));
}
