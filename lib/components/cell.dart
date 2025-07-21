
class Cell {
  final int x, y;
  bool isBomb = false;
  bool isRevealed = false;
  int adjacentBombs = 0;
  bool isFlagged = false;

  Cell(this.x, this.y);

  factory Cell.fromJson(Map<String, dynamic> json) {
    var cell = Cell(
      json['x'],
      json['y'],
      // json['isBomb'],
      // json['isRevealed'],
      // json['adjacentBombs'],
    );
    cell.isBomb = json['isBomb'];
    cell.isRevealed = json['isRevealed'];
    cell.adjacentBombs = json['adjacentBombs'];
    cell.isFlagged = json['isFlagged'];
    return cell;
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'isBomb': isBomb,
    'isRevealed': isRevealed,
    'adjacentBombs': adjacentBombs,
    'isFlagged': isFlagged
  };
}
