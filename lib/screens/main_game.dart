import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/minesweeper.dart';

class MainGame extends StatelessWidget {
  const MainGame({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: Minesweeper());
  }
}
