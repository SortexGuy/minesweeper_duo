import 'dart:math';

import 'package:minesweeper_duo/components/cell.dart';

class BoardController {
  final int rows;
  final int cols;
  final int mineCount;
  late List<List<Cell>> board;

  BoardController(this.rows, this.cols, this.mineCount) {
    _generateBoard();
  }

  void _generateBoard() {
    board = List.generate(rows, (r) => List.generate(cols, (c) => Cell(r, c)));
    _placeMines();
    _calculateNeighbors();
  }

  void _placeMines() {
    var rand = Random();
    int placed = 0;
    while (placed < mineCount) {
      int r = rand.nextInt(rows);
      int c = rand.nextInt(cols);
      if (!board[r][c].isBomb) {
        board[r][c].isBomb = true;
        placed++;
      }
    }
  }

  void _calculateNeighbors() {
    for (var row in board) {
      for (var cell in row) {
        if (cell.isBomb) continue;
        int count = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            int nr = cell.y + dr;
            int nc = cell.x + dc;
            if (_isInBounds(nr, nc) && board[nr][nc].isBomb) {
              count++;
            }
          }
        }
        cell.adjacentBombs = count;
      }
    }
  }

  bool _isInBounds(int r, int c) {
    return r >= 0 && r < rows && c >= 0 && c < cols;
  }

  void revealCell(int r, int c) {
    final cell = board[r][c];
    if (cell.isRevealed) return;

    cell.isRevealed = true;

    if (cell.adjacentBombs == 0 && !cell.isBomb) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          int nr = r + dr;
          int nc = c + dc;
          if (_isInBounds(nr, nc)) revealCell(nr, nc);
        }
      }
    }
  }
}
