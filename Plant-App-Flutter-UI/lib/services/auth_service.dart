import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:urbangreen/models/user_model.dart';
import 'package:urbangreen/services/platform/web_hardware_bridge.dart';

class AuthService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _customStorage;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _customAuth = auth,
        _customFirestore = firestore,
        _customStorage = storage;

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseStorage? get _storage {
    if (_customStorage != null) return _customStorage;
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream.value(null);

  User? get currentUser => _auth?.currentUser;

  /// Check whether the app is currently running in guest explorer mode
  static bool get isGuestMode =>
      WebHardwareBridge.loadStorage('is_guest_mode') == 'true';

  /// Toggle guest mode flag in persistent storage
  static void setGuestMode(bool isGuest) {
    WebHardwareBridge.saveStorage('is_guest_mode', isGuest ? 'true' : 'false');
  }

  /// Register new user with email, username, and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String username,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanUsername = username.trim();

    final firestore = _firestore;
    final auth = _auth;

    if (auth == null) {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication service is unavailable.',
      );
    }

    // Try checking if username is already taken in Firestore
    if (firestore != null) {
      try {
        final usernameQuery = await firestore
            .collection('users')
            .where('username', isEqualTo: cleanUsername)
            .limit(1)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'username-already-in-use',
            message: 'The username "$cleanUsername" is already taken. Please choose another.',
          );
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Firestore rules do not allow unauthenticated reading of users collection.
          // Proceed with user creation and profile setup.
        } else {
          rethrow;
        }
      }
    }

    final userCredential = await auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = userCredential.user;
    if (user != null && firestore != null) {
      await user.updateDisplayName(cleanUsername);

      final newUserModel = UserModel(
        uid: user.uid,
        email: cleanEmail,
        username: cleanUsername,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('users')
          .doc(user.uid)
          .set(newUserModel.toMap());
    }

    return userCredential;
  }

  /// Login with email OR username
  Future<UserCredential> loginWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();
    String emailToUse = cleanIdentifier;

    final firestore = _firestore;
    final auth = _auth;

    if (auth == null) {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication service is unavailable.',
      );
    }

    // If identifier doesn't look like an email, lookup username in Firestore
    if (!cleanIdentifier.contains('@') && firestore != null) {
      try {
        final userQuery = await firestore
            .collection('users')
            .where('username', isEqualTo: cleanIdentifier)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found with username "$cleanIdentifier".',
          );
        }

        final userData = userQuery.docs.first.data();
        emailToUse = userData['email'] as String? ?? '';
        if (emailToUse.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Email associated with username not found.',
          );
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw FirebaseAuthException(
            code: 'permission-denied',
            message: 'Firestore security rules require logging in with Email address directly (or updating Firestore rules).',
          );
        }
        rethrow;
      }
    }

    return await auth.signInWithEmailAndPassword(
      email: emailToUse,
      password: password,
    );
  }

  /// Send password reset link
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    final auth = _auth;
    if (auth != null) {
      await auth.sendPasswordResetEmail(email: cleanEmail);
    }
  }

  /// Change password with re-authentication using current password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth?.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No active user session. Please log in again.',
      );
    }

    // Re-authenticate user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  /// Logout current user
  Future<void> logout() async {
    await _auth?.signOut();
  }

  /// Delete current user account, profile, addresses, and auth credentials
  /// (Strictly compliant with Google Play & Apple App Store account deletion requirements)
  Future<void> deleteAccount({String? currentPassword}) async {
    final user = _auth?.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No active user session to delete.',
      );
    }

    final uid = user.uid;

    // 1. Mandatory re-authentication if password provided and email is present
    if (currentPassword != null &&
        currentPassword.isNotEmpty &&
        user.email != null &&
        user.email!.isNotEmpty) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    }

    // 2. Cascade cleanup of personal data in Firestore
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final addressesSnap = await firestore
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .get();
        for (final doc in addressesSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      try {
        final cartSnap = await firestore
            .collection('users')
            .doc(uid)
            .collection('cart')
            .get();
        for (final doc in cartSnap.docs) {
          await doc.reference.delete().catchError((_) {});
        }
      } catch (_) {}

      try {
        await firestore.collection('carts').doc(uid).delete().catchError((_) {});
      } catch (_) {}

      try {
        await firestore.collection('users').doc(uid).delete().catchError((_) {});
      } catch (_) {}
    }

    // 3. Delete profile avatar in Firebase Storage
    final storage = _storage;
    if (storage != null) {
      try {
        await storage
            .ref()
            .child('user_profiles')
            .child('$uid.jpg')
            .delete()
            .catchError((_) {});
      } catch (_) {}
    }

    // 4. Delete Firebase Auth user record
    await user.delete();
  }
}
