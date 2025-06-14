// ignore_for_file: avoid_print

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'host_minesweeper.dart';

class P2PMinesweeperGame extends FlameGame with TapDetector {
  // Game constants
  static const int gridSize = 10;
  static const int bombCount = 15;
  static const double cellSize = 40.0;

  // Game state
  late List<List<Cell>> grid;
  bool gameOver = false;
  bool gameWon = false;

  late MinesweeperHost? _host;
  late io.Socket socket;
  String? gameId;
  int? playerIndex;
  int currentPlayer = 0;
  bool isHost = false;
  String? hostIp;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    if (isHost) {
      _host = MinesweeperHost(gridSize, bombCount);
      gameId = _host!.gameId;
    }
  }

  Future<void> connectToHost(String ip) async {
    hostIp = ip;
    socket = io.io('http://$ip:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      if (!isHost) {
        print("Join requested");
        socket.emit('join_request', {'gameId': gameId});
      }
    });

    socket.on('game_state', (data) {
      if (data['gameId'] == gameId) {
        playerIndex = data['playerIndex'];
        currentPlayer = data['currentPlayer'];

        // Initialize grid from host data
        grid =
            (data['grid'] as List)
                .map<List<Cell>>(
                  (row) =>
                      (row as List)
                          .map<Cell>(
                            (cell) => Cell(
                              cell['x'],
                              cell['y'],
                              cell['isBomb'],
                              cell['isRevealed'],
                              cell['adjacentBombs'],
                            ),
                          )
                          .toList(),
                )
                .toList();
      }
    });

    socket.on('cell_revealed', (data) {
      if (data['gameId'] == gameId) {
        grid[data['x']][data['y']].isRevealed = true;
        grid[data['x']][data['y']].isBomb = data['isBomb'];
        currentPlayer = data['currentPlayer'];
      }
    });

    socket.on('game_over', (data) {
      if (data['gameId'] == gameId) {
        gameOver = true;
        gameWon = data['winner'] == playerIndex;
      }
    });
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (playerIndex == null || currentPlayer != playerIndex) return;

    final position = info.eventPosition.global;
    final x = (position.x / cellSize).floor();
    final y = (position.y / cellSize).floor();

    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      socket.emit('reveal_cell', {
        'gameId': gameId,
        'x': x,
        'y': y,
        'playerIndex': playerIndex,
      });
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Add player status
    final status =
        playerIndex == null
            ? 'Connecting...'
            : currentPlayer == playerIndex
            ? 'Your turn'
            : 'Opponent\'s turn';

    final textPainter = TextPainter(
      text: TextSpan(
        text: status,
        style: TextStyle(
          color: currentPlayer == playerIndex ? Colors.green : Colors.red,
          fontSize: 24,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(10, size.y - 30));

    // Show connection info
    if (isHost) {
      final ipText = TextPainter(
        text: TextSpan(
          text: 'Host IP: ${hostIp ?? 'Loading...'}\nGame ID: $gameId',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ipText.paint(canvas, Offset(10, 10));
    }
  }
}
