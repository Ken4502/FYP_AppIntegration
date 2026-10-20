import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String? id;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  bool isDefault;

  Address({
    this.id,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'isDefault': isDefault,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Address.fromMap(Map<String, dynamic> map, String docId) {
    return Address(
      id: docId,
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zipCode'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }

  factory Address.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Address.fromMap(data, doc.id);
  }

  Address copyWith({
    String? id,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
