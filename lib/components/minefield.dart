import 'package:flame/components.dart';

class Cell extends PositionComponent {
  @override
  bool get debugMode => true;
}

// class CenterComponent extends PositionComponent {
//   CenterComponent()
//       : super(
//           position: Vector2(100, 100),
//           size: Vector2(50, 50),
//           anchor: Anchor.center,
//         );

//   @override
//   Future<void> onLoad() async {
//     await add(
//       PositionComponent(position: Vector2(0, -50)),
//     );
//   }
// }