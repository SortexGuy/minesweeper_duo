import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:minesweeper_duo/components/cell.dart';

class Minesweeper extends FlameGame with TapDetector {
  // Game constants
  static const int gridSize = 10;
  static const int bombCount = 15;
  static const double cellSize = 40.0;

  // Game state
  late List<List<Cell>> grid;
  bool gameOver = false;
  bool gameWon = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    Random rand = Random(1);
    // await Flame.images.load('klondike-sprites.png');

    // Create empty grid
    grid = List.generate(
      gridSize,
      (x) => List.generate(gridSize, (y) => Cell(x, y)),
    );

    // Place bombs randomly
    var bombsPlaced = 0;
    while (bombsPlaced < bombCount) {
      final x = rand.nextInt(gridSize);
      final y = rand.nextInt(gridSize);

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
  void onRemove() {
    super.onRemove();

    grid = List.empty();
    gameOver = false;
    gameWon = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw grid
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        final cell = grid[x][y];
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
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
              Offset(x * cellSize + cellSize / 2, y * cellSize + cellSize / 2),
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
                y * cellSize + cellSize / 2 - textPainter.height / 2,
              ),
            );
          }
        }
      }
    }

    // Draw game over message
    if (gameOver || gameWon) {
      final text = gameOver ? 'Game Over!' : 'You Win!';
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

  @override
  void update(double dt) {
    super.update(dt);
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
  void onTapDown(TapDownInfo info) {
    if (gameOver || gameWon) {
      // Restart game
      gameOver = false;
      gameWon = false;

      var context = buildContext!;
      Navigator.pop(context);
      return;
    }

    final position = info.eventPosition.widget;
    final x = (position.x / cellSize).floor();
    final y = (position.y / cellSize).floor();

    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      revealCell(x, y);
    }
  }

  void revealCell(int x, int y) {
    if (grid[x][y].isRevealed) return;

    grid[x][y].isRevealed = true;

    if (grid[x][y].isBomb) {
      // Reveal all bombs
      for (var row in grid) {
        for (var cell in row) {
          if (cell.isBomb) cell.isRevealed = true;
        }
      }
      gameOver = true;
      return;
    }

    // If cell has no adjacent bombs, reveal adjacent cells
    if (grid[x][y].adjacentBombs == 0) {
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
            revealCell(nx, ny);
          }
        }
      }
    }

    // Check for win condition
    checkWin();
  }

  void checkWin() {
    var unrevealedSafeCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (!cell.isBomb && !cell.isRevealed) {
          unrevealedSafeCells++;
        }
      }
    }
    if (unrevealedSafeCells == 0) {
      gameWon = true;
    }
  }

  @override
  Color backgroundColor() => const Color(0x00000000);
}
