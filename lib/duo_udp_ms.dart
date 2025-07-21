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
import 'package:minesweeper_duo/components/board_controller.dart';
import 'package:minesweeper_duo/components/cell.dart';
import 'package:minesweeper_duo/components/events.dart';
import 'package:udp/udp.dart';

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
    }
  }
}

class MinesweeperGame extends FlameGame with HoverCallbacks {
  final bool isHost;
  final InternetAddress? localIp;
  final Port? port;

  UDP? udpSocket;
  InternetAddress? remoteAddress;
  Port? remotePort;
  String gameId = "";
  ConnectionStatus cStatus = ConnectionStatus.waiting;
  String connectionStatus = 'Initializing...';
  bool isConnected = false;
  int? playerIndex;
  int currentPlayer = 0;
  bool gameOver = false;
  bool gameWon = false;

  // Connection management
  Timer? pingTimer;
  Timer? connectionTimeoutTimer;
  DateTime? lastPongReceived;
  static const Duration pingInterval = Duration(seconds: 5);
  static const Duration connectionTimeout = Duration(seconds: 15);

  // Game settings
  static const int gridSize = 10;
  static const int bombCount = 15;
  static const double cellSize = 40.0;
  late BoardController boardController;

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

    boardController = BoardController(gridSize, gridSize, bombCount);

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
      await _startUDPServer();
    } else {
      await _connectToHost();
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
    if (isConnected) {
      _drawGrid(canvas);
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

  // Dentro de void _drawGrid(Canvas canvas)
  void _drawGrid(Canvas canvas) {
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        final cell = boardController.board[x][y];
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize + 50, // Offset para la barra de estado
          cellSize,
          cellSize,
        );

        // Draw cell background
        final paint = Paint()
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

        // Dibujar contenido
        if (cell.isRevealed) {
          if (cell.isBomb) {
            // Dibujar bomba
            canvas.drawCircle(
              Offset(
                x * cellSize + cellSize / 2,
                y * cellSize + 50 + cellSize / 2,
              ),
              cellSize / 3,
              Paint()..color = Colors.black,
            );
          } else if (cell.adjacentBombs > 0) {
            // Dibujar número
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
        } else if (cell.isFlagged) { // <-- Si la celda no está revelada PERO está marcada
          // Dibujar una bandera (puedes usar un triángulo o un icono más elaborado)
          final flagPaint = Paint()..color = Colors.red;
          final path = Path();
          path.moveTo(x * cellSize + cellSize * 0.25, y * cellSize + 50 + cellSize * 0.75); // Base izquierda
          path.lineTo(x * cellSize + cellSize * 0.75, y * cellSize + 50 + cellSize * 0.75); // Base derecha
          path.lineTo(x * cellSize + cellSize * 0.5, y * cellSize + 50 + cellSize * 0.25); // Punta superior
          path.close();
          canvas.drawPath(path, flagPaint);

          // O una forma más simple, un "F" de "Flag"
          final flagTextPainter = TextPainter(
            text: const TextSpan(
              text: '🚩', // Un emoji de bandera es simple y efectivo
              style: TextStyle(
                fontSize: cellSize * 0.7, // Ajusta el tamaño
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          flagTextPainter.paint(
            canvas,
            Offset(
              x * cellSize + cellSize / 2 - flagTextPainter.width / 2,
              y * cellSize + 50 + cellSize / 2 - flagTextPainter.height / 2,
            ),
          );
        }
      }
    }
  }

  Future<void> _startUDPServer() async {
    try {
      udpSocket = await UDP.bind(
        Endpoint.unicast(
          localIp ?? InternetAddress.anyIPv4,
          port: port ?? Port(3000),
        ),
      );

      connectionStatus = 'Waiting for player...';

      // Listen for incoming messages
      udpSocket!.asStream().listen((datagram) {
        if (datagram != null) {
          _handleUDPMessage(datagram);
        }
      });

      // Start connection timeout timer
      connectionTimeoutTimer = Timer(
        connectionTimeout.inSeconds.toDouble(),
        onTick: () {
          if (!isConnected) {
            connectionStatus = 'Connection timeout - no player joined';
            cStatus = ConnectionStatus.closed;
          }
        },
      );
    } catch (e) {
      connectionStatus = 'Error starting server: $e';
    }
  }

  Future<void> _connectToHost() async {
    try {
      udpSocket = await UDP.bind(Endpoint.any());

      // Set remote address
      remoteAddress = localIp ?? InternetAddress.loopbackIPv4;
      remotePort = port ?? Port(3000);

      connectionStatus = 'Connecting to host...';

      // Listen for incoming messages
      udpSocket!.asStream().listen((datagram) {
        if (datagram != null) {
          _handleUDPMessage(datagram);
        }
      });

      // Send initial connection message
      await _sendEvent(Event.fromNotify('Client connecting'));

      // Start connection timeout timer
      connectionTimeoutTimer = Timer(
        connectionTimeout.inSeconds.toDouble(),
        onTick: () {
          if (!isConnected) {
            connectionStatus = 'Connection timeout - host not responding';
            cStatus = ConnectionStatus.closed;
          }
        },
      );
    } catch (e) {
      connectionStatus = 'Connection failed: $e';
    }
  }

  void _handleUDPMessage(Datagram datagram) {
    try {
      final message = String.fromCharCodes(datagram.data);
      final event = Event.fromJson(jsonDecode(message));

      // Store remote address for responses (for host)
      if (isHost && remoteAddress == null) {
        remoteAddress = datagram.address;
        remotePort = Port(datagram.port);

        // Connection established
        isConnected = true;
        cStatus = ConnectionStatus.connected;
        connectionStatus = 'Player connected!';
        playerIndex = 0;

        // Cancel timeout timer
        connectionTimeoutTimer?.stop();

        // Start the game
        _sendEvent(Event.fromStart(boardController.board, 1, currentPlayer));

        // Start ping timer
        _startPingTimer();
      } else if (!isHost && !isConnected) {
        // Client receiving first response from host
        isConnected = true;
        connectionStatus = 'Connected to host!';
        cStatus = ConnectionStatus.connected;

        // Cancel timeout timer
        connectionTimeoutTimer?.stop();

        // Start ping timer
        _startPingTimer();
      }

      _handleNetworkEvents(event);
    } catch (e) {
      print('Error handling UDP message: $e');
    }
  }

  void _handleNetworkEvents(Event event) {
    switch (event.type) {
      case EventType.start:
        boardController.board =
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
        final x = event.data['x'];
        final y = event.data['y'];
        boardController.revealCell(x, y);
        currentPlayer = event.data['currentPlayer'];
        break;

      case EventType.revealCell:
        final x = event.data['x'];
        final y = event.data['y'];
        boardController.revealCell(x, y);
        currentPlayer = (currentPlayer + 1) % 2;
        _sendEvent(Event.fromGameUpdate(x, y, currentPlayer));
        break;

      case EventType.gameOver:
        gameOver = true;
        gameWon = event.data['winner'] == playerIndex;
        _stopPingTimer();
        break;

      case EventType.notify:
        connectionStatus = event.data['message'];
        break;

      case EventType.error:
        connectionStatus = event.data['message'];
        break;

      case EventType.ping:
        // Respond with pong
        _sendEvent(Event.fromPong());
        break;

      case EventType.pong:
        // Update last pong received time
        lastPongReceived = DateTime.now();
        break;
    }
  }

  Future<void> _sendEvent(Event event) async {
    if (udpSocket != null && remoteAddress != null && remotePort != null) {
      try {
        final message = jsonEncode(event.toJson());
        final data = Uint8List.fromList(message.codeUnits);

        await udpSocket!.send(
          data,
          Endpoint.unicast(remoteAddress!, port: remotePort!),
        );
      } catch (e) {
        print('Error sending UDP message: $e');
      }
    }
  }

  void _startPingTimer() {
    lastPongReceived = DateTime.now();
    pingTimer = Timer(
      pingInterval.inSeconds.toDouble(),
      repeat: true,
      onTick: () {
        if (isConnected) {
          _sendEvent(Event.fromPing());

          // Check if connection is still alive
          if (lastPongReceived != null &&
              DateTime.now().difference(lastPongReceived!) >
                  connectionTimeout) {
            _handleConnectionLost();
          }
        }
      },
    );
  }

  void _stopPingTimer() {
    pingTimer?.stop();
    pingTimer = null;
  }

  void _handleConnectionLost() {
    isConnected = false;
    cStatus = ConnectionStatus.closed;
    connectionStatus = 'Connection lost!';
    _stopPingTimer();
    connectionTimeoutTimer?.stop();
  }

  void handleTap(Offset position) {
    if (gameOver) {
      return;
    }

    if (playerIndex == null || currentPlayer != playerIndex) return;

    final x = (position.dx / cellSize).floor();
    final y = ((position.dy - 50) / cellSize).floor(); // Ajuste para la barra de estado

    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) return;

    final cell = boardController.board[x][y];

    if (cell.isRevealed || cell.isFlagged) {
      // No hacer nada si la celda ya está revelada o si tiene una bandera
      return;
    }

    _handleCellReveal(x, y); // Revelar la celda
  }

  // Método para manejar el toque largo (móvil) o clic derecho (PC) para la bandera
  void handleFlagAction(Offset position) {
    if (gameOver) return;
    if (playerIndex == null || currentPlayer != playerIndex) return;

    final x = (position.dx / cellSize).floor();
    final y = ((position.dy - 50) / cellSize).floor(); // Ajuste para la barra de estado

    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) return;

    final cell = boardController.board[x][y];

    if (cell.isRevealed) {
      // No puedes poner banderas en celdas reveladas
      return;
    }

    // Alternar el estado de la bandera
    _handleCellFlag(x, y, !cell.isFlagged);
  }

  void _handleCellFlag(int x, int y, bool flagStatus) {
    var cell = boardController.board[x][y];
    if (cell.isRevealed) {
      return; // No se pueden marcar/desmarcar celdas reveladas
    }

    cell.isFlagged = flagStatus; // Actualiza el estado de la bandera
  }

  void _handleCellReveal(int x, int y) {
    var grid = boardController.board;
    boardController.revealCell(x, y);

    // Switch turns
    currentPlayer = (currentPlayer + 1) % 2;
    _sendEvent(Event.fromGameUpdate(x, y, currentPlayer));

    if (grid[x][y].isBomb) {
      gameOver = true;
      gameWon = false;
      _sendEvent(Event.fromGameOver((playerIndex! + 1) % 2));
      return;
    }

    // Check for win condition
    _checkWinCondition();
  }

  void _checkWinCondition() {
    var unrevealedSafeCells = 0;
    for (var row in boardController.board) {
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

  @override
  void onRemove() {
    super.onRemove();
    _stopPingTimer();
    connectionTimeoutTimer?.stop();
    udpSocket?.close();
  }
}



