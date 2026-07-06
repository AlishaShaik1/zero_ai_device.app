/// Central configuration file.
/// Update [searchGatewayUrl] after deploying your Render server.
class AppConfig {
  AppConfig._();

  /// Base URL for the Zero Search Gateway server.
  /// Change this single line after Render deployment.
  static const String searchGatewayUrl = 'https://search-server-theta.vercel.app';

  /// API key for the search gateway.
  /// Using a compile-time environment value keeps the secret out of code.
  static const String searchGatewayApiKey = String.fromEnvironment(
    'ZERO_SEARCH_API_KEY',
    defaultValue: 'zerotech1234',
  );
}
