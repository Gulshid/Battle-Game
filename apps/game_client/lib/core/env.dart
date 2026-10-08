class Env {
  static const apiUrl = String.fromEnvironment('API_URL');
  static const gameWs = String.fromEnvironment('GAME_WS');
  static const debugHud = bool.fromEnvironment('DEBUG_HUD');
}
