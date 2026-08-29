/// The overall status of a game at the current position.
///
/// Note: `check` and `ongoing` are both "the game continues" states —
/// `check` just additionally tells the UI to highlight the king. The
/// three draw variants are separated (rather than one generic `draw`) so
/// the UI/analysis layer can display *why* the game drew.
enum GameStatus {
  ongoing,
  check,
  checkmate,
  stalemate,
  drawFiftyMoveRule,
  drawInsufficientMaterial,
  drawThreefoldRepetition;

  bool get isGameOver =>
      this == GameStatus.checkmate ||
      this == GameStatus.stalemate ||
      this == GameStatus.drawFiftyMoveRule ||
      this == GameStatus.drawInsufficientMaterial ||
      this == GameStatus.drawThreefoldRepetition;

  bool get isDraw =>
      this == GameStatus.stalemate ||
      this == GameStatus.drawFiftyMoveRule ||
      this == GameStatus.drawInsufficientMaterial ||
      this == GameStatus.drawThreefoldRepetition;
}
