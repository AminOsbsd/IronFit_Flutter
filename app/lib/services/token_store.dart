import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton de session.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

/// Jeton chiffré par le système (Keystore Android, DPAPI Windows, WebCrypto sur le Web).
/// Si le stockage sécurisé est indisponible (ex. Flutter Web hors HTTPS), le jeton reste
/// en mémoire uniquement : il faudra se reconnecter au prochain lancement, mais il n'est jamais écrit en clair.
class SecureTokenStore implements TokenStore {
  static const _key = 'ironfit_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _memory;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key) ?? _memory;
    } catch (_) {
      return _memory;
    }
  }

  @override
  Future<void> write(String? token) async {
    _memory = token;
    try {
      token == null ? await _storage.delete(key: _key) : await _storage.write(key: _key, value: token);
    } catch (_) {}
  }
}

/// Stockage en mémoire (tests).
class MemoryTokenStore implements TokenStore {
  String? token;
  MemoryTokenStore([this.token]);
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String? t) async => token = t;
}
