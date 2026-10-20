import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Stream user profile document in real-time
  Stream<UserModel?> getUserProfileStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromDocument(doc) : null);
  }

  /// Get user profile document once
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  /// Update username in Firestore and Firebase Auth
  Future<void> updateUsername(String uid, String newUsername) async {
    final cleanUsername = newUsername.trim();

    // Check if new username is taken by another user
    final existingUserQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (existingUserQuery.docs.isNotEmpty &&
        existingUserQuery.docs.first.id != uid) {
      throw Exception('The username "$cleanUsername" is already taken.');
    }

    // Update Firestore
    await _firestore.collection('users').doc(uid).update({
      'username': cleanUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update Firebase Auth display name
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updateDisplayName(cleanUsername);
    }
  }

  /// Update user profile picture
  Future<String> updateProfilePicture(String uid, XFile imageFile) async {
    String downloadUrl = '';
    try {
      final ref = _storage.ref().child('user_profiles').child('$uid.jpg');
      await ref.putFile(File(imageFile.path));
      downloadUrl = await ref.getDownloadURL();
    } catch (_) {
      // Fallback if Storage bucket isn't available: store local path or placeholder URL
      downloadUrl = imageFile.path;
    }

    // Update Firestore
    await _firestore.collection('users').doc(uid).update({
      'photoUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update Firebase Auth
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updatePhotoURL(downloadUrl);
    }

    return downloadUrl;
  }

  // --- ADDRESS MANAGEMENT ---

  /// Stream address list for user
  Stream<List<Address>> getAddressesStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Address.fromDocument(doc)).toList());
  }

  /// Add new address
  Future<void> addAddress(String uid, Address address) async {
    final addressesRef =
        _firestore.collection('users').doc(uid).collection('addresses');

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

    final docRef = _firestore
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
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }

  /// Set default address
  Future<void> setDefaultAddress(String uid, String addressId) async {
    await _unsetDefaultAddresses(uid);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .doc(addressId)
        .update({'isDefault': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Helper to unset default status for addresses
  Future<void> _unsetDefaultAddresses(String uid, {String? excludeDocId}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      if (excludeDocId != null && doc.id == excludeDocId) continue;
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}
