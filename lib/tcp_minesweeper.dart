import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:minesweeper_duo/components/board_controller.dart';
import 'package:minesweeper_duo/components/cell.dart';
import 'package:minesweeper_duo/components/events.dart';

enum ConnectionStatus { waiting, connected, closed }

extension ConnectionStatusExtension on ConnectionStatus {
  String get name {
    switch (this) {
      case ConnectionStatus.waiting:
        return 'Waiting for other player';
      case ConnectionStatus.connected:
        return 'Connection established!!';
      case ConnectionStatus.closed:
        return 'Connection closed!';
    }
  }
}

class MinesweeperGame extends FlameGame with HoverCallbacks {
  final bool isHost;
  final InternetAddress? localIp;
  final int? port;

  // Assets
  late Sprite bombSprite;
  late Sprite flagSprite;

  // TCP Connection
  ServerSocket? serverSocket;
  Socket? clientSocket;
  Socket? gameSocket; // The active socket for communication
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
  static const Duration connectionTimeout = Duration(seconds: 25);
  StreamSubscription? socketSubscription;

  // Game settings
  static const int gridSize = 10;
  static const int bombCount = 15;
  static const double cellSize = 40.0;
  late BoardController boardController;

  // UI elements
  late TextBoxComponent statusText;
  late TextBoxComponent ipDisplay;

  // Color palette for cells
  static const Color _unrevealedCellColor = Color(0xFFC0C0C0); // Light gray
  static const Color _revealedCellColor = Color(
    0xFFE0E0E0,
  ); // Very light gray, almost white
  static const Color _lightEdgeColor = Color(
    0xFFFFFFFF,
  ); // White for highlights
  static const Color _darkEdgeColor = Color(
    0xFF808080,
  ); // Dark gray for shadows
  static const double _borderWidth = 3.0; // Shading border width

  MinesweeperGame({
    required this.isHost,
    required this.localIp,
    required this.port,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    boardController = BoardController(gridSize, gridSize, bombCount);

    bombSprite = await loadSprite('bomb.png');
    flagSprite = await loadSprite('flag.png');

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
      await _startTCPServer();
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
      final text = gameWon ? 'You Win!' : 'Game Over!';
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
        final cell = boardController.board[x][y];
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize + 50, // Offset for top status bar
          cellSize,
          cellSize,
        );

        // --- 2.1. Draw cell background ---
        final cellPaint = Paint();
        if (cell.isRevealed) {
          cellPaint.color =
              _revealedCellColor; // Light gray background for revealed cell
        } else {
          cellPaint.color =
              _unrevealedCellColor; // Gray background for unrevealed cell
        }
        canvas.drawRect(rect, cellPaint);

        // --- 2.2. Draw borders for 3D effect ---
        if (cell.isRevealed) {
          // Revealed cells: "Sunken" border
          // Top and left borders darker (shadow)
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, _borderWidth),
            Paint()..color = _darkEdgeColor,
          ); // Top border
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, _borderWidth, rect.height),
            Paint()..color = _darkEdgeColor,
          ); // Left border

          // Bottom and right borders lighter (light)
          canvas.drawRect(
            Rect.fromLTWH(
              rect.right - _borderWidth,
              rect.top,
              _borderWidth,
              rect.height,
            ),
            Paint()..color = _lightEdgeColor,
          ); // Right border
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left,
              rect.bottom - _borderWidth,
              rect.width,
              _borderWidth,
            ),
            Paint()..color = _lightEdgeColor,
          ); // Bottom border
        } else {
          // Unrevealed cells: "Raised" border (simulates button)
          // Top and left borders lighter (light)
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, _borderWidth),
            Paint()..color = _lightEdgeColor,
          ); // Top border
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, _borderWidth, rect.height),
            Paint()..color = _lightEdgeColor,
          ); // Left border

          // Bottom and right borders darker (shadow)
          canvas.drawRect(
            Rect.fromLTWH(
              rect.right - _borderWidth,
              rect.top,
              _borderWidth,
              rect.height,
            ),
            Paint()..color = _darkEdgeColor,
          ); // Right border
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left,
              rect.bottom - _borderWidth,
              rect.width,
              _borderWidth,
            ),
            Paint()..color = _darkEdgeColor,
          ); // Bottom border
        }

        // --- 2.3. Draw cell content (bomb, number, flag) ---
        if (cell.isRevealed) {
          if (cell.isBomb) {
            // Draw bomb sprite
            bombSprite.render(
              canvas,
              position: Vector2(
                x * cellSize + cellSize / 2, // Center X of cell
                y * cellSize +
                    50 +
                    cellSize / 2, // Center Y of cell (with offset)
              ),
              size: Vector2.all(
                cellSize * 0.9,
              ), // Sprite size (90% of cell size)
              anchor: Anchor.center, // Draw sprite centered at position
            );
          } else if (cell.adjacentBombs > 0) {
            // Draw number of adjacent bombs
            final textPainter = TextPainter(
              text: TextSpan(
                text: cell.adjacentBombs.toString(),
                style: TextStyle(
                  color: _getNumberColor(
                    cell.adjacentBombs,
                  ), // Use existing color function
                  fontSize: cellSize / 2, // Font size (50% of cell size)
                  fontWeight: FontWeight.bold, // Bold numbers
                ),
              ),
              textDirection: TextDirection.ltr, // Text direction
            )..layout(); // Calculate text layout

            // Draw centered text in cell
            textPainter.paint(
              canvas,
              Offset(
                x * cellSize +
                    cellSize / 2 -
                    textPainter.width / 2, // X position to center
                y * cellSize +
                    50 +
                    cellSize / 2 -
                    textPainter.height /
                        2, // Y position to center (with offset)
              ),
            );
          }
        } else if (cell.isFlagged) {
          // If cell is not revealed but is flagged
          // Draw flag sprite
          flagSprite.render(
            canvas,
            position: Vector2(
              x * cellSize + cellSize / 2, // Center X of cell
              y * cellSize +
                  50 +
                  cellSize / 2, // Center Y of cell (with offset)
            ),
            size: Vector2.all(cellSize * 0.9), // Sprite size
            anchor: Anchor.center, // Draw sprite centered at position
          );
        }
      }
    }
  }

  Future<void> _startTCPServer() async {
    try {
      debugPrint("!!!! Binding to ${localIp!}:${port!}");
      serverSocket = await ServerSocket.bind(localIp!, port!);

      connectionStatus = 'Waiting for player on port ${serverSocket!.port}';

      // Listen for incoming connections
      serverSocket!.listen((Socket socket) {
        if (gameSocket == null) {
          // Accept the first connection
          gameSocket = socket;
          isConnected = true;
          cStatus = ConnectionStatus.connected;
          connectionStatus = 'Player connected!';
          playerIndex = 0;

          // Cancel timeout timer
          connectionTimeoutTimer?.stop();

          // Set up socket listener
          _setupSocketListener(socket);

          // Start the game
          _sendEvent(Event.fromStart(boardController.board, 1, currentPlayer));

          // Start ping timer
          _startPingTimer();
        } else {
          // Reject additional connections
          socket.close();
        }
      });

      // Start connection timeout timer
      connectionTimeoutTimer = Timer(
        connectionTimeout.inSeconds.toDouble(),
        onTick: () {
          if (!isConnected) {
            connectionStatus = 'Connection timeout - no player joined';
            cStatus = ConnectionStatus.closed;
            serverSocket?.close();
          }
        },
      );
    } catch (e) {
      connectionStatus = 'Error starting server: $e';
    }
  }

  Future<void> _connectToHost() async {
    try {
      debugPrint("!!!! Connecting to ${localIp!}:${port!}");
      connectionStatus = 'Connecting to host on ${localIp!}:${port!}';

      // Connect to the host
      gameSocket = await Socket.connect(
        localIp!,
        port!,
        timeout: connectionTimeout,
      );

      isConnected = true;
      connectionStatus = 'Connected to host!';
      cStatus = ConnectionStatus.connected;
      print("!!!!! Connected to host");

      // Set up socket listener
      _setupSocketListener(gameSocket!);

      // Cancel timeout timer
      connectionTimeoutTimer?.stop();

      // Send initial connection message
      await _sendEvent(Event.fromNotify('Client connecting'));

      // Start ping timer
      _startPingTimer();
    } catch (e, stackTrace) {
      dev.log("Connection failed: ${e}", error: e, stackTrace: stackTrace);
      debugPrint("Connection failed: ${e}");
      connectionStatus = 'Connection failed: $e';
      cStatus = ConnectionStatus.closed;
    }
  }

  void _setupSocketListener(Socket socket) {
    socketSubscription = socket
        .transform(
          StreamTransformer.fromBind((inStream) {
            final stream = Utf8Decoder().bind(inStream);
            return LineSplitter().bind(stream);
          }),
        )
        .listen(
          (String message) {
            _handleTCPMessage(message);
          },
          onError: (error) {
            print('Socket error: $error');
            _handleConnectionLost();
          },
          onDone: () {
            print('Socket connection closed');
            _handleConnectionLost();
          },
        );
  }

  void _handleTCPMessage(String message) {
    try {
      final event = Event.fromJson(jsonDecode(message));

      // Handle initial connection for client
      if (!isHost && playerIndex == null && event.type == EventType.start) {
        playerIndex = event.data['playerIndex'];
      }

      _handleNetworkEvents(event);
    } catch (e) {
      print('Error handling TCP message: $e');
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
        if (playerIndex == null) {
          playerIndex = event.data['playerIndex'];
        }
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
    if (gameSocket != null) {
      try {
        final message = jsonEncode(event.toJson()) + '\n';
        gameSocket!.write(message);
        await gameSocket!.flush();
      } catch (e) {
        print('Error sending TCP message: $e');
        _handleConnectionLost();
      }
    }
  }

  void _startPingTimer() {
    lastPongReceived = DateTime.now();
    pingTimer = Timer(
      pingInterval.inSeconds.toDouble(),
      onTick: () {
        if (isConnected) {
          _sendEvent(Event.fromPing());

          // Check if connection is still alive
          if (lastPongReceived != null &&
              DateTime.now().difference(lastPongReceived!) >
                  connectionTimeout) {
            _handleConnectionLost();
          }
        } else {
          pingTimer?.stop();
        }
      },
      repeat: true,
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

    // Close sockets
    socketSubscription?.cancel();
    gameSocket?.close();
    serverSocket?.close();
  }

  void handleTap(Offset position) {
    if (gameOver) {
      return;
    }

    if (playerIndex == null || currentPlayer != playerIndex) return;

    final x = (position.dx / cellSize).floor();
    final y = ((position.dy - 50) / cellSize).floor(); // Adjust for status bar

    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) return;

    final cell = boardController.board[x][y];

    if (cell.isRevealed || cell.isFlagged) {
      // Do nothing if cell is already revealed or has a flag
      return;
    }

    _handleCellReveal(x, y); // Reveal the cell
  }

  // Method to handle long press (mobile) or right click (PC) for flag
  void handleFlagAction(Offset position) {
    if (gameOver) return;
    if (playerIndex == null || currentPlayer != playerIndex) return;

    final x = (position.dx / cellSize).floor();
    final y = ((position.dy - 50) / cellSize).floor(); // Adjust for status bar

    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) return;

    final cell = boardController.board[x][y];

    if (cell.isRevealed) {
      // Cannot put flags on revealed cells
      return;
    }

    // Toggle flag state
    _handleCellFlag(x, y, !cell.isFlagged);
  }

  void _handleCellFlag(int x, int y, bool flagStatus) {
    var cell = boardController.board[x][y];
    if (cell.isRevealed) {
      return; // Cannot flag/unflag revealed cells
    }

    cell.isFlagged = flagStatus; // Update flag state
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
    socketSubscription?.cancel();
    gameSocket?.close();
    serverSocket?.close();
  }
}

