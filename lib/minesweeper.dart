import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flutter/rendering.dart';

class Minesweeper extends FlameGame {
  @override
  Future<void> onLoad() async {
    // await Flame.images.load('klondike-sprites.png');
    add(CenterComponent());
  }

  @override
  Color backgroundColor() => const Color(0x00000000);
  // Sprite minesweeperSprite(double x, double y, double width, double height) {
  //   return Sprite(
  //     Flame.images.fromCache('klondike-sprites.png'),
  //     srcPosition: Vector2(x, y),
  //     srcSize: Vector2(width, height),
  //   );
  // }
}


class CenterComponent extends PositionComponent {
  CenterComponent()
      : super(
          position: Vector2(0, 100),
          size: Vector2(200, 200),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await add(
      PositionComponent(position: Vector2(0, -100)),
    );
  }
}