import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart'; 
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

  // Assets
  late Sprite bombSprite;
  late Sprite flagSprite;

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

  // Paleta de colores para las celdas
  static const Color _unrevealedCellColor = Color(0xFFC0C0C0); // Gris claro
  static const Color _revealedCellColor = Color(0xFFE0E0E0);   // Gris muy claro, casi blanco
  static const Color _lightEdgeColor = Color(0xFFFFFFFF);     // Blanco para luces
  static const Color _darkEdgeColor = Color(0xFF808080);      // Gris oscuro para sombras
  static const double _borderWidth = 3.0; // Ancho del borde de sombreado



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

  // Dentro de void _drawGrid(Canvas canvas)
void _drawGrid(Canvas canvas) {
  for (var x = 0; x < gridSize; x++) {
    for (var y = 0; y < gridSize; y++) {
      final cell = boardController.board[x][y];
      final rect = Rect.fromLTWH(
        x * cellSize,
        y * cellSize + 50, // Offset para la barra de estado superior
        cellSize,
        cellSize,
      );

      // --- 2.1. Dibujar el fondo de la celda ---
      final cellPaint = Paint();
      if (cell.isRevealed) {
        cellPaint.color = _revealedCellColor; // Fondo gris claro para celda revelada
      } else {
        cellPaint.color = _unrevealedCellColor; // Fondo gris para celda sin revelar
      }
      canvas.drawRect(rect, cellPaint);

      // --- 2.2. Dibujar los bordes para el efecto 3D ---
      if (cell.isRevealed) {
        // Celdas reveladas: Borde "hundido"
        // Bordes superiores e izquierdos más oscuros (sombra)
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, _borderWidth),
          Paint()..color = _darkEdgeColor,
        ); // Borde superior
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, _borderWidth, rect.height),
          Paint()..color = _darkEdgeColor,
        ); // Borde izquierdo

        // Bordes inferiores y derechos más claros (luz)
        canvas.drawRect(
          Rect.fromLTWH(rect.right - _borderWidth, rect.top, _borderWidth, rect.height),
          Paint()..color = _lightEdgeColor,
        ); // Borde derecho
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - _borderWidth, rect.width, _borderWidth),
          Paint()..color = _lightEdgeColor,
        ); // Borde inferior

      } else {
        // Celdas sin revelar: Borde "elevado" (simula un botón)
        // Bordes superiores e izquierdos más claros (luz)
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, _borderWidth),
          Paint()..color = _lightEdgeColor,
        ); // Borde superior
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, _borderWidth, rect.height),
          Paint()..color = _lightEdgeColor,
        ); // Borde izquierdo

        // Bordes inferiores y derechos más oscuros (sombra)
        canvas.drawRect(
          Rect.fromLTWH(rect.right - _borderWidth, rect.top, _borderWidth, rect.height),
          Paint()..color = _darkEdgeColor,
        ); // Borde derecho
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - _borderWidth, rect.width, _borderWidth),
          Paint()..color = _darkEdgeColor,
        ); // Borde inferior
      }

      // --- 2.3. Dibujar el contenido de la celda (bomba, número, bandera) ---
      if (cell.isRevealed) {
        if (cell.isBomb) {
          // Dibujar el sprite de la bomba
          bombSprite.render(
            canvas,
            position: Vector2(
              x * cellSize + cellSize / 2,         // Centro X de la celda
              y * cellSize + 50 + cellSize / 2,   // Centro Y de la celda (con offset)
            ),
            size: Vector2.all(cellSize * 0.9),    // Tamaño del sprite (90% del tamaño de la celda)
            anchor: Anchor.center,                // Dibuja el sprite centrado en su posición
          );
        } else if (cell.adjacentBombs > 0) {
          // Dibujar el número de bombas adyacentes
          final textPainter = TextPainter(
            text: TextSpan(
              text: cell.adjacentBombs.toString(),
              style: TextStyle(
                color: _getNumberColor(cell.adjacentBombs), // Usa tu función de color existente
                fontSize: cellSize / 2,                     // Tamaño de la fuente (50% del tamaño de la celda)
                fontWeight: FontWeight.bold,                // Números en negrita
              ),
            ),
            textDirection: TextDirection.ltr, // Dirección del texto
          )..layout(); // Calcular el layout del texto

          // Dibujar el texto centrado en la celda
          textPainter.paint(
            canvas,
            Offset(
              x * cellSize + cellSize / 2 - textPainter.width / 2,       // Posición X para centrar
              y * cellSize + 50 + cellSize / 2 - textPainter.height / 2, // Posición Y para centrar (con offset)
            ),
          );
        }
      } else if (cell.isFlagged) {
        // Si la celda no está revelada pero está marcada con una bandera
        // Dibujar el sprite de la bandera
        flagSprite.render(
          canvas,
          position: Vector2(
            x * cellSize + cellSize / 2,         // Centro X de la celda
            y * cellSize + 50 + cellSize / 2,   // Centro Y de la celda (con offset)
          ),
          size: Vector2.all(cellSize * 0.9),    // Tamaño del sprite
          anchor: Anchor.center,                // Dibuja el sprite centrado en su posición
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



