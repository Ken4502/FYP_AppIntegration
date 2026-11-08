import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/models/user_model.dart';

class UserService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final FirebaseStorage? _customStorage;

  UserService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customStorage = storage;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
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

  /// Stream user profile document in real-time
  Stream<UserModel?> getUserProfileStream(String uid) {
    final fs = _firestore;
    if (fs == null) return Stream.value(null);
    return fs
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDocument(doc) : null);
  }

  /// Get user profile document once
  Future<UserModel?> getUserProfile(String uid) async {
    final fs = _firestore;
    if (fs == null) return null;
    final doc = await fs.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  /// Update username in Firestore and Firebase Auth
  Future<void> updateUsername(String uid, String newUsername) async {
    final cleanUsername = newUsername.trim();
    final fs = _firestore;
    if (fs == null) return;

    // Check if new username is taken by another user
    final existingUserQuery = await fs
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (existingUserQuery.docs.isNotEmpty &&
        existingUserQuery.docs.first.id != uid) {
      throw Exception('The username "$cleanUsername" is already taken.');
    }

    // Update Firestore
    await fs.collection('users').doc(uid).update({
      'username': cleanUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update Firebase Auth display name
    final currentUser = _auth?.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updateDisplayName(cleanUsername);
    }
  }

  /// Update user profile picture
  Future<String> updateProfilePicture(String uid, XFile imageFile) async {
    String downloadUrl = '';
    final storage = _storage;
    if (storage != null) {
      try {
        final ref = storage.ref().child('user_profiles').child('$uid.jpg');
        await ref.putFile(File(imageFile.path));
        downloadUrl = await ref.getDownloadURL();
      } catch (_) {
        downloadUrl = imageFile.path;
      }
    } else {
      downloadUrl = imageFile.path;
    }

    // Update Firestore
    final fs = _firestore;
    if (fs != null) {
      await fs.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update Firebase Auth
    final currentUser = _auth?.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updatePhotoURL(downloadUrl);
    }

    return downloadUrl;
  }

  // --- ADDRESS MANAGEMENT ---

  /// Stream address list for user
  Stream<List<Address>> getAddressesStream(String uid) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);
    return fs
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Address.fromDocument(doc)).toList());
  }

  /// Add new address
  Future<void> addAddress(String uid, Address address) async {
    final fs = _firestore;
    if (fs == null) return;
    final addressesRef =
        fs.collection('users').doc(uid).collection('addresses');

    // If marked as default, unset previous default addresses
    if (address.isDefault) {
      await _unsetDefaultAddresses(uid);
    } else {
      // If this is the first address, automatically make it default
      final countSnap = await addressesRef.get();
      if (countSnap.docs.isEmpty) {
        address.isDefault = true;
      }
    }

    await addressesRef.add(address.toMap());
  }

  /// Update existing address
  Future<void> updateAddress(String uid, Address address) async {
    if (address.id == null || address.id!.isEmpty) return;
    final fs = _firestore;
    if (fs == null) return;

    final docRef = fs
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(address.id);

    if (address.isDefault) {
      await _unsetDefaultAddresses(uid, excludeDocId: address.id);
    }

    await docRef.update(address.toMap());
  }

  /// Delete address
  Future<void> deleteAddress(String uid, String addressId) async {
    final fs = _firestore;
    if (fs == null) return;
    await fs
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  /// Set default address
  Future<void> setDefaultAddress(String uid, String addressId) async {
    final fs = _firestore;
    if (fs == null) return;
    await _unsetDefaultAddresses(uid);
    await fs
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .update({'isDefault': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Helper to unset default status for addresses
  Future<void> _unsetDefaultAddresses(String uid, {String? excludeDocId}) async {
    final fs = _firestore;
    if (fs == null) return;
    final snapshot = await fs
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = fs.batch();
    for (var doc in snapshot.docs) {
      if (excludeDocId != null && doc.id == excludeDocId) continue;
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}
