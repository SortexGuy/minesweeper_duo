// ignore_for_file: avoid_print

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';

class MinesweeperHost {
  final int gridSize;
  final int bombCount;
  late io.Socket socket;
  late List<List<Cell>> grid;
  List<io.Socket> clients = [];
  int currentPlayer = 0;
  String gameId = "";
  // String gameId = const Uuid().v4();

  MinesweeperHost(this.gridSize, this.bombCount) {
    initializeGrid();
    _setupSocketServer();
  }

  Future<String> getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP() ?? '127.0.0.1';
  }

  void _setupSocketServer() async {
    final ip = await getLocalIp();
    print('Host IP: $ip');

    socket = io.io('http://$ip:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('Host connected to signaling server');
    });

    socket.on('join_request', (data) {
      if (clients.length < 2) {
        print("Attempting Connect");
        // Limit to 2 players for simplicity
        final clientSocket = data['socket'];
        clients.add(clientSocket);

        // Send initial game state to new player
        clientSocket.emit('game_state', {
          'grid':
              grid
                  .map((row) => row.map((cell) => cell.toJson()).toList())
                  .toList(),
          'currentPlayer': currentPlayer,
          'playerIndex': clients.length - 1,
          'gameId': gameId,
        });

        // Notify all players about new connection
        print("Client Connected");
        _broadcast('player_joined', {'playerCount': clients.length});
      }
    });

    socket.on('reveal_cell', (data) {
      final playerIndex = data['playerIndex'];
      if (playerIndex == currentPlayer) {
        final x = data['x'];
        final y = data['y'];
        _handleCellReveal(x, y, playerIndex);
      }
    });

    socket.open();
    socket.connect();
  }

  void _handleCellReveal(int x, int y, int playerIndex) {
    grid[x][y].isRevealed = true;

    // Check for game over conditions
    if (grid[x][y].isBomb) {
      _broadcast('game_over', {'winner': (playerIndex + 1) % 2});
      return;
    }

    // Switch turns
    currentPlayer = (currentPlayer + 1) % clients.length;

    _broadcast('cell_revealed', {
      'x': x,
      'y': y,
      'isBomb': grid[x][y].isBomb,
      'currentPlayer': currentPlayer,
    });
  }

  void _broadcast(String event, dynamic data) {
    for (final client in clients) {
      client.emit(event, data);
    }
  }

  void initializeGrid() {
    // Same grid initialization as before
    grid = List.generate(
      gridSize,
      (x) => List.generate(gridSize, (y) => Cell(x, y, false, false, 0)),
    );

    // Place bombs and calculate adjacent counts
    // (Same logic as previous implementation)
  }
}

class Cell {
  final int x, y;
  bool isBomb;
  bool isRevealed;
  int adjacentBombs;

  Cell(this.x, this.y, this.isBomb, this.isRevealed, this.adjacentBombs);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'isBomb': isBomb,
    'isRevealed': isRevealed,
    'adjacentBombs': adjacentBombs,
  };
}
