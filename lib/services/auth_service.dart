import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth + Google Sign-In for the optional "sign in to sync"
/// feature. Nothing else in the app depends on this — Prakriyā works fully
/// offline; signing in only adds a cloud copy of your data under your own
/// Google account.
///
/// Every member here is safe to call even when `Firebase.initializeApp()`
/// never ran or failed (missing config, a widget test, no network at
/// startup) — sign-in/sync just reports itself unavailable instead of
/// throwing, since `FirebaseAuth.instance` throws immediately otherwise.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // The Web (type 3) OAuth client from google-services.json — Android needs
  // this passed as the serverClientId to get a verifiable ID token back.
  static const _serverClientId =
      '191375066674-nfovb3noep8q4e0kqanill93emno1r8f.apps.googleusercontent.com';

  bool _initialized = false;

  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth => isAvailable ? FirebaseAuth.instance : null;

  User? get currentUser => _auth?.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get userChanges =>
      _auth?.authStateChanges() ?? Stream<User?>.value(null);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Returns the signed-in user, or null if unavailable, the sheet was
  /// dismissed, or something went wrong (no network, no Google account on
  /// the device).
  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) return null;
    await _ensureInitialized();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential =
          GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (_) {
      return null;
    }
  }

  /// Optional Drive backup only. `drive.file` lets Prakriyā touch just the one
  /// backup file it creates in the user's Drive — nothing else. Asked for only
  /// when the user taps "Back up to Google Drive". Silent when already granted;
  /// with [interactive] it shows Google's consent sheet. Returns null if
  /// unavailable or not granted.
  static const driveScope = 'https://www.googleapis.com/auth/drive.file';

  Future<String?> driveToken({bool interactive = false}) async {
    if (!isAvailable || !isSignedIn) return null;
    try {
      await _ensureInitialized();
      final client = GoogleSignIn.instance.authorizationClient;
      var auth = await client.authorizationForScopes([driveScope]);
      if (auth == null && interactive) {
        auth = await client.authorizeScopes([driveScope]);
      }
      return auth?.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// Drops a cached token Google rejected, so the next call fetches a fresh one.
  Future<void> clearDriveToken(String token) async {
    try {
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
    } catch (_) {}
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) return;
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google this session — fine, still sign out of Firebase below.
    }
    await auth.signOut();
  }
}
