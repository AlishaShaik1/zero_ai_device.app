/// Central configuration file.
/// Update [searchGatewayUrl] after deploying your Render server.
class AppConfig {
  AppConfig._();

  /// Base URL for the Zero Search Gateway server.
  /// Change this single line after Render deployment.
  static const String searchGatewayUrl = 'https://YOUR-APP.onrender.com';
}
