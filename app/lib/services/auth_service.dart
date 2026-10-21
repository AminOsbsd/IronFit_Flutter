import '../core/network/api_client.dart';
import '../models/app_user.dart';

/// Connexion, inscription, mot de passe oublié, profil et mot de passe.
class AuthService {
  AuthService._();

  static Future<void> login(String loginOrEmail, String password) async =>
      Api.setSession(await Api.post('login', {'login': loginOrEmail, 'password': password}));

  static Future<void> signup({required String name, required String login, required String email, required String password}) async =>
      Api.setSession(await Api.post('signup', {'name': name, 'login': login, 'email': email, 'password': password}));

  /// Renvoie le code de démonstration si le serveur est en mode démo (SHOW_RESET_CODE), sinon null.
  static Future<String?> forgotPassword(String email) async => (await Api.post('forgot', {'email': email}))['dev_code'] as String?;

  static Future<void> resetPassword({required String email, required String code, required String password}) =>
      Api.post('reset', {'email': email, 'code': code, 'password': password});

  static Future<void> refreshMe() => Api.refreshMe();

  static Future<void> updateProfile({required String name, required String email, String? phone, String? specialty}) async {
    final r = await Api.call('PUT', 'profile', {'name': name, 'email': email, 'phone': phone, 'specialty': ?specialty});
    Api.user = AppUser.fromJson(Map<String, dynamic>.from(r as Map));
  }

  /// Le serveur révoque les anciens jetons et renvoie celui de la session courante.
  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final r = await Api.post('password', {'old': oldPassword, 'new': newPassword});
    await Api.setToken(r['token'] as String);
  }

  static Future<void> logout() => Api.logout();
}
