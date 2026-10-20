import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbangreen/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Register new user with email, username, and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String username,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanUsername = username.trim();

    // Try checking if username is already taken in Firestore
    try {
      final usernameQuery = await _firestore
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

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      await user.updateDisplayName(cleanUsername);

      final newUserModel = UserModel(
        uid: user.uid,
        email: cleanEmail,
        username: cleanUsername,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
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

    // If identifier doesn't look like an email, lookup username in Firestore
    if (!cleanIdentifier.contains('@')) {
      try {
        final userQuery = await _firestore
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

    return await _auth.signInWithEmailAndPassword(
      email: emailToUse,
      password: password,
    );
  }

  /// Send password reset link
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  /// Change password with re-authentication using current password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
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
    await _auth.signOut();
  }
}
