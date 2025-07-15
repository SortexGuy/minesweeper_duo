
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
