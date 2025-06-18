import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/screens/p2p_lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Flame.device.fullScreen();
  Flame.device.setPortrait();

  runApp(
    MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const P2PLobbyScreen(),
    ),
  );
}
