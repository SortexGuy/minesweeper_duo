import 'package:minesweeper_duo/components/cell.dart';


enum EventType {
  start,
  gameUpdate,
  revealCell,
  gameOver,
  notify,
  error,
  ping,
  pong,
}
class Event {
  final EventType type;
  final dynamic data;

  Event(this.data, {required this.type});

  factory Event.fromJson(Map<String, dynamic> json) =>
      Event(json['data'], type: EventType.values[json['type']]);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.index,
    'data': data,
  };

  factory Event.fromStart(
    List<List<Cell>> grid,
    int playerIdx,
    int currPlayer,
  ) => Event(<String, dynamic>{
    'grid': grid,
    'playerIndex': playerIdx,
    'currentPlayer': currPlayer,
  }, type: EventType.start);

  factory Event.fromGameUpdate(int x, int y, int currPlayer) => Event(
    <String, dynamic>{'x': x, 'y': y, 'currentPlayer': currPlayer},
    type: EventType.gameUpdate,
  );

  factory Event.fromRevealCell(int x, int y) =>
      Event(<String, dynamic>{'x': x, 'y': y}, type: EventType.revealCell);

  factory Event.fromGameOver(int winner) =>
      Event(<String, dynamic>{'winner': winner}, type: EventType.gameOver);

  factory Event.fromNotify(String message) =>
      Event(<String, dynamic>{'message': message}, type: EventType.notify);

  factory Event.fromError(String message) =>
      Event(<String, dynamic>{'message': message}, type: EventType.error);

  factory Event.fromPing() => Event(null, type: EventType.ping);

  factory Event.fromPong() => Event(null, type: EventType.pong);
}