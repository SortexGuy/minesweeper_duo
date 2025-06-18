import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

enum ConnectionStatus { waiting, connected, closed }

extension ConnectionStatusExtension on ConnectionStatus {
  String get name {
    switch (this) {
      case ConnectionStatus.waiting:
        return 'Waiting for other player';
      case ConnectionStatus.connected:
        return 'Connection stablished!!';
      case ConnectionStatus.closed:
        return 'Connection closed!';
      // default:
      //   return 'Not a Connection Status Code';
    }
  }
}

enum EventType { start, gameUpdate, revealCell, gameOver, notify, error }

class Event {
  final EventType type;
  final dynamic data;

  Event(this.data, {required this.type});

  factory Event.fromJson(Map<String, dynamic> json) =>
      Event(json['data'], type: EventType.values[int.parse(json['type'])]);
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.index,
    'data': data,
  };

  factory Event.fromStart(dynamic grid, int playerIdx, int currPlayer) =>
      Event(<String, dynamic>{
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
}

class MinesweeperGame extends FlameGame with TapDetector, HoverCallbacks {
  final bool isHost;
  final String? localIp;
  final String? port;

  Socket? socket;
  ServerSocket? server;
  String gameId = ""; // const Uuid().v4();
  ConnectionStatus cStatus = ConnectionStatus.waiting;
  String connectionStatus = 'Initializing...';
  bool isConnected = false;
  int? playerIndex;
  int currentPlayer = 0;
  bool gameOver = false;
  bool gameWon = false;

  // Game settings
  static const int gridSize = 10;
  static const int bombCount = 15;
  static const double cellSize = 40.0;
  late List<List<Cell>> grid;

  // UI elements
  late TextBoxComponent statusText;
  late TextBoxComponent ipDisplay;

  MinesweeperGame({
    required this.isHost,
    required this.localIp,
    required this.port,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    socket = null;
    initializeGrid();

    // Setup UI components
    statusText = TextBoxComponent(
      text: connectionStatus,
      anchor: Anchor.bottomLeft,
      position: Vector2(30, size.y - 30),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.red, fontSize: 16),
      ),
    );

    if (isHost) {
      if (server == null) {
        _startServer();
      }
      // _getLocalIp();
    } else {
      _connectToHost();
    }

    // Add connection UI if not connected
    if (!isConnected) {
      //   add(_buildConnectionUI());
    }
    add(statusText);
  }

  @override
  void update(double dt) {
    super.update(dt);
    statusText.text = connectionStatus;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw grid
    if (!isConnected) {
      // _drawGrid(canvas);
    }

    // Draw turn indicator
    if (playerIndex != null) {
      final turnText =
          currentPlayer == playerIndex ? 'Your turn' : 'Opponent\'s turn';
      final textPainter = TextPainter(
        text: TextSpan(
          text: turnText,
          style: TextStyle(
            color: currentPlayer == playerIndex ? Colors.green : Colors.red,
            fontSize: 20,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.x - textPainter.width - 10, 10));
    }

    // Draw game over message
    if (gameOver) {
      final text = gameWon ? 'You Won!' : 'Game Over!';
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          size.x / 2 - textPainter.width / 2,
          size.y / 2 - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawGrid(Canvas canvas) {
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        final cell = grid[x][y];
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize + 50, // Offset for status bar
          cellSize,
          cellSize,
        );

        // Draw cell background
        final paint =
            Paint()
              ..color = cell.isRevealed ? Colors.white : Colors.grey
              ..style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);

        // Draw border
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        // Draw content
        if (cell.isRevealed) {
          if (cell.isBomb) {
            // Draw bomb
            canvas.drawCircle(
              Offset(
                x * cellSize + cellSize / 2,
                y * cellSize + 50 + cellSize / 2,
              ),
              cellSize / 3,
              Paint()..color = Colors.black,
            );
          } else if (cell.adjacentBombs > 0) {
            // Draw number
            final textPainter = TextPainter(
              text: TextSpan(
                text: cell.adjacentBombs.toString(),
                style: TextStyle(
                  color: _getNumberColor(cell.adjacentBombs),
                  fontSize: cellSize / 2,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            textPainter.paint(
              canvas,
              Offset(
                x * cellSize + cellSize / 2 - textPainter.width / 2,
                y * cellSize + 50 + cellSize / 2 - textPainter.height / 2,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _startServer() async {
    try {
      server = await ServerSocket.bind(
        localIp ?? InternetAddress.anyIPv4,
        int.parse(port ?? '3000'),
      );
      connectionStatus = 'Waiting for player...';

      server!.listen((Socket client) {
        if (socket != null) {
          client.write(jsonEncode(Event.fromError('Game is full')));
          client.close();
          return;
        }
        socket = client;
        client.listen(
          _handleNetworkEvents,
          onError: (error) {
            connectionStatus = 'Connection error: $error';
          },
          onDone: () {
            isConnected = false;
            cStatus = ConnectionStatus.closed;
            connectionStatus = 'Connection closed';
          },
        );
        isConnected = true;
        cStatus = ConnectionStatus.connected;
        connectionStatus = 'Player connected!';
        playerIndex = 0;

        _sendEvent(
          Event.fromStart(
            grid
                .map((row) => row.map((cell) => cell.toJson()).toList())
                .toList(),
            1,
            currentPlayer,
          ),
        );
        _sendEvent(Event.fromNotify('Sucessfuly connected!!!'));
      });
    } catch (e) {
      connectionStatus = 'Error: $e';
    }
  }

  Future<void> _connectToHost() async {
    try {
      socket = await Socket.connect(
        localIp ?? InternetAddress.loopbackIPv4,
        int.parse(port ?? '3000'),
      );

      _setupSocketListeners();
      isConnected = true;
      connectionStatus = 'Connected to host!';
    } catch (e) {
      connectionStatus = 'Connection failed: $e';
    }
  }

  void _setupSocketListeners() {
    socket!.listen(
      _handleNetworkEvents,
      onError: (error) {
        connectionStatus = 'Connection error: $error';
        cStatus = ConnectionStatus.closed;
      },
      onDone: () {
        isConnected = false;
        cStatus = ConnectionStatus.closed;
        connectionStatus = 'Connection closed';
      },
    );
  }

  void _handleNetworkEvents(Uint8List data) {
    final message = jsonDecode(String.fromCharCodes(data));
    Event event = Event.fromJson(message);
    switch (event.type) {
      case EventType.start:
        grid =
            (event.data['grid'] as List)
                .map<List<Cell>>(
                  (row) =>
                      (row as List)
                          .map<Cell>((cell) => Cell.fromJson(cell))
                          .toList(),
                )
                .toList();
        playerIndex = event.data['playerIndex'];
        currentPlayer = event.data['currentPlayer'];
        break;

      case EventType.gameUpdate:
        grid[event.data['x']][event.data['y']].isRevealed = true;
        currentPlayer = event.data['currentPlayer'];
        break;

      case EventType.revealCell:
        grid[event.data['x']][event.data['y']].isRevealed = true;
        break;

      case EventType.gameOver:
        gameOver = true;
        gameWon = event.data['winner'] == playerIndex;
        break;

      case EventType.notify:
        connectionStatus = event.data['message'];
        break;

      case EventType.error:
        connectionStatus = event.data['message'];
        break;
    }
  }

  Future<void> _sendEvent(Event event) async {
    if (socket != null) {
      final msg = event.toJson();
      String json = jsonEncode(msg);
      print(json);
      socket!.write(json);
      await socket!.flush();
    }
  }

  void initializeGrid() {
    grid = List.generate(
      gridSize,
      (x) => List.generate(gridSize, (y) => Cell(x, y, false, false, 0)),
    );

    // Place bombs randomly
    var bombsPlaced = 0;
    final random = Random();
    while (bombsPlaced < bombCount) {
      final x = random.nextInt(gridSize);
      final y = random.nextInt(gridSize);

      if (!grid[x][y].isBomb) {
        grid[x][y].isBomb = true;
        bombsPlaced++;

        // Update adjacent cells' bomb counts
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
              grid[nx][ny].adjacentBombs++;
            }
          }
        }
      }
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameOver || playerIndex == null || currentPlayer != playerIndex) return;

    final position = info.eventPosition.widget;
    final x = (position.x / cellSize).floor();
    final y = ((position.y - 50) / cellSize).floor(); // Adjust for status bar

    if (x >= 0 &&
        x < gridSize &&
        y >= 0 &&
        y < gridSize &&
        !grid[x][y].isRevealed) {
      if (isHost) {
        // Host validates the move
        _handleCellReveal(x, y);
      } else {
        // Client sends move to host
        _sendEvent(Event.fromRevealCell(x, y));
      }
    }
  }

  void _handleCellReveal(int x, int y) {
    grid[x][y].isRevealed = true;

    // Switch turns
    currentPlayer = (currentPlayer + 1) % 2;
    _sendEvent(Event.fromGameUpdate(x, y, currentPlayer));

    if (grid[x][y].isBomb) {
      _sendEvent(Event.fromGameOver((playerIndex! + 1) % 2));
      gameOver = true;
      gameWon = false;
      return;
    }

    // Check for win condition
    _checkWinCondition();
  }

  void _checkWinCondition() {
    var unrevealedSafeCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (!cell.isBomb && !cell.isRevealed) {
          unrevealedSafeCells++;
        }
      }
    }
    if (unrevealedSafeCells == 0) {
      _sendEvent(Event.fromGameOver(playerIndex!));
      gameOver = true;
      gameWon = true;
    }
  }

  Color _getNumberColor(int number) {
    switch (number) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.brown;
      case 6:
        return Colors.teal;
      case 7:
        return Colors.black;
      case 8:
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
}

class Cell {
  final int x, y;
  bool isBomb;
  bool isRevealed;
  int adjacentBombs;

  Cell(this.x, this.y, this.isBomb, this.isRevealed, this.adjacentBombs);

  factory Cell.fromJson(Map<String, dynamic> json) {
    return Cell(
      json['x'],
      json['y'],
      json['isBomb'],
      json['isRevealed'],
      json['adjacentBombs'],
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'isBomb': isBomb,
    'isRevealed': isRevealed,
    'adjacentBombs': adjacentBombs,
  };
}
