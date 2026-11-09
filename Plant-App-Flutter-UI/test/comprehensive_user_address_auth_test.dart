import 'package:flutter_test/flutter_test.dart';
import 'package:urbangreen/models/address_model.dart';
import 'package:urbangreen/models/user_model.dart';

void main() {
  group('Malaysian State & Postcode Validation Matrix (16 Regions)', () {
    final malaysianStates = [
      {'state': 'Wilayah Persekutuan Kuala Lumpur', 'code': '50000', 'valid': true},
      {'state': 'Wilayah Persekutuan Putrajaya', 'code': '62000', 'valid': true},
      {'state': 'Wilayah Persekutuan Labuan', 'code': '87000', 'valid': true},
      {'state': 'Selangor', 'code': '47301', 'valid': true},
      {'state': 'Selangor (Petaling Jaya)', 'code': '46000', 'valid': true},
      {'state': 'Penang (George Town)', 'code': '10000', 'valid': true},
      {'state': 'Johor (Johor Bahru)', 'code': '80000', 'valid': true},
      {'state': 'Perak (Ipoh)', 'code': '30000', 'valid': true},
      {'state': 'Kedah (Alor Setar)', 'code': '05000', 'valid': true},
      {'state': 'Kelantan (Kota Bharu)', 'code': '15000', 'valid': true},
      {'state': 'Melaka', 'code': '75000', 'valid': true},
      {'state': 'Negeri Sembilan (Seremban)', 'code': '70000', 'valid': true},
      {'state': 'Pahang (Kuantan)', 'code': '25000', 'valid': true},
      {'state': 'Perlis (Kangar)', 'code': '01000', 'valid': true},
      {'state': 'Sabah (Kota Kinabalu)', 'code': '88000', 'valid': true},
      {'state': 'Sarawak (Kuching)', 'code': '93000', 'valid': true},
    ];

    final postcodeRegex = RegExp(r'^[0-9]{5}$');

    for (final reg in malaysianStates) {
      test('Valid Malaysian postcode ${reg['code']} for ${reg['state']}', () {
        final code = reg['code'] as String;
        final isValid = postcodeRegex.hasMatch(code);
        expect(isValid, equals(reg['valid']));

        final address = Address(
          id: 'addr_my_${reg['code']}',
          street: '12 Jalan Bunga Raya',
          city: (reg['state'] as String).split(' ').last,
          state: reg['state'] as String,
          zipCode: code,
          isDefault: true,
        );

        expect(address.zipCode, equals(code));
        expect(address.state, equals(reg['state']));
        expect(address.isDefault, isTrue);
      });
    }
  });

  group('Postcode Boundary & Malformed Inputs Matrix (15 Cases)', () {
    final invalidPostcodes = [
      {'input': '1234', 'reason': 'Too short (4 digits)'},
      {'input': '123456', 'reason': 'Too long (6 digits)'},
      {'input': '5000A', 'reason': 'Alphanumeric containing letter'},
      {'input': 'ABCDE', 'reason': 'All alphabets'},
      {'input': '-5000', 'reason': 'Negative sign prefix'},
      {'input': ' 5000', 'reason': 'Leading whitespace'},
      {'input': '50000 ', 'reason': 'Trailing whitespace'},
      {'input': '50 00', 'reason': 'Internal whitespace'},
      {'input': '50.00', 'reason': 'Floating point dot'},
      {'input': '500@0', 'reason': 'Special character @'},
      {'input': '00000', 'reason': 'Reserved all-zeros'},
      {'input': '!@#\$%', 'reason': 'Symbols only'},
      {'input': '5000\n', 'reason': 'Newline character'},
      {'input': '5000\t', 'reason': 'Tab character'},
      {'input': '', 'reason': 'Empty string'},
    ];

    final strictPostcodeRegex = RegExp(r'^(?!00000)[0-9]{5}$');

    for (final item in invalidPostcodes) {
      test('Rejection of invalid postcode "${item['input']}" (${item['reason']})', () {
        final isValid = strictPostcodeRegex.hasMatch(item['input'] as String);
        expect(isValid, isFalse, reason: 'Expected invalid: ${item['reason']}');
      });
    }
  });

  group('Address Model Immutability & CopyWith Matrix (20 Permutations)', () {
    final baseAddress = Address(
      id: 'addr_base_001',
      street: '42 Orchid Lane',
      city: 'Shah Alam',
      state: 'Selangor',
      zipCode: '40000',
      isDefault: false,
    );

    for (int i = 1; i <= 10; i++) {
      test('copyWith mutation for street and zipCode iteration #$i', () {
        final modified = baseAddress.copyWith(
          street: 'Jalan $i, Section $i',
          zipCode: '${40000 + i}',
        );

        expect(modified.id, equals(baseAddress.id));
        expect(modified.city, equals('Shah Alam'));
        expect(modified.state, equals('Selangor'));
        expect(modified.street, equals('Jalan $i, Section $i'));
        expect(modified.zipCode, equals('${40000 + i}'));
        expect(modified.isDefault, isFalse);
      });
    }

    for (int i = 1; i <= 10; i++) {
      test('copyWith mutation for default toggle and city iteration #$i', () {
        final isDef = i % 2 == 0;
        final modified = baseAddress.copyWith(
          city: 'City #$i',
          isDefault: isDef,
        );

        expect(modified.city, equals('City #$i'));
        expect(modified.isDefault, equals(isDef));
        expect(modified.street, equals(baseAddress.street));
      });
    }
  });

  group('Address Model Map Deserialization & Robust Fallbacks (15 Cases)', () {
    final mapCases = [
      {'map': <String, dynamic>{}, 'id': 'doc_01', 'expStreet': '', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'street': 'Lot 10'}, 'id': 'doc_02', 'expStreet': 'Lot 10', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'city': 'Subang Jaya'}, 'id': 'doc_03', 'expStreet': '', 'expCity': 'Subang Jaya', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'state': 'Selangor'}, 'id': 'doc_04', 'expStreet': '', 'expCity': '', 'expState': 'Selangor', 'expZip': '', 'expDef': false},
      {'map': {'zipCode': '47500'}, 'id': 'doc_05', 'expStreet': '', 'expCity': '', 'expState': '', 'expZip': '47500', 'expDef': false},
      {'map': {'isDefault': true}, 'id': 'doc_06', 'expStreet': '', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': true},
      {'map': {'street': '1st Ave', 'city': 'Klang', 'state': 'Selangor', 'zipCode': '41000', 'isDefault': true}, 'id': 'doc_07', 'expStreet': '1st Ave', 'expCity': 'Klang', 'expState': 'Selangor', 'expZip': '41000', 'expDef': true},
      {'map': {'street': null, 'city': null}, 'id': 'doc_08', 'expStreet': '', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'street': 'No 5', 'isDefault': null}, 'id': 'doc_09', 'expStreet': 'No 5', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'state': 'Johor', 'zipCode': '80200'}, 'id': 'doc_10', 'expStreet': '', 'expCity': '', 'expState': 'Johor', 'expZip': '80200', 'expDef': false},
      {'map': {'city': 'Georgetown', 'zipCode': '10100'}, 'id': 'doc_11', 'expStreet': '', 'expCity': 'Georgetown', 'expState': '', 'expZip': '10100', 'expDef': false},
      {'map': {'street': 'Unit A', 'city': 'Kuching'}, 'id': 'doc_12', 'expStreet': 'Unit A', 'expCity': 'Kuching', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'street': 'Jalan Hang Tuah', 'city': 'Melaka'}, 'id': 'doc_13', 'expStreet': 'Jalan Hang Tuah', 'expCity': 'Melaka', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'isDefault': false}, 'id': 'doc_14', 'expStreet': '', 'expCity': '', 'expState': '', 'expZip': '', 'expDef': false},
      {'map': {'street': 'Penthouse 9', 'city': 'KL', 'state': 'WP', 'zipCode': '50450', 'isDefault': true}, 'id': 'doc_15', 'expStreet': 'Penthouse 9', 'expCity': 'KL', 'expState': 'WP', 'expZip': '50450', 'expDef': true},
    ];

    for (int i = 0; i < mapCases.length; i++) {
      final c = mapCases[i];
      test('Address.fromMap resilience test case #${i + 1}', () {
        final addr = Address.fromMap(c['map'] as Map<String, dynamic>, c['id'] as String);
        expect(addr.id, equals(c['id']));
        expect(addr.street, equals(c['expStreet']));
        expect(addr.city, equals(c['expCity']));
        expect(addr.state, equals(c['expState']));
        expect(addr.zipCode, equals(c['expZip']));
        expect(addr.isDefault, equals(c['expDef']));
      });
    }
  });

  group('User Profile Email Validation Matrix (25 Cases)', () {
    final emailRegex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z]{1,})+$");

    final validEmails = [
      'gardener@urbangreen.com',
      'user.name@example.org',
      'plant_lover123@garden.net',
      'botanist+tag@domain.co.uk',
      'my-species@sub.domain.my',
      'sarah.tan@malaysia.com.my',
      'ken_ficus@greenery.asia',
      'admin@urban-flora.my',
      'x@y.z',
      'test.email.123@gmail.com',
      'specimen@botany.edu',
      'contact@nurseries.com',
    ];

    for (final email in validEmails) {
      test('Valid email pattern: $email', () {
        expect(emailRegex.hasMatch(email), isTrue);
      });
    }

    final invalidEmails = [
      'plainaddress',
      '@missingusername.com',
      'username@.com',
      'username@domain',
      'user name@domain.com',
      'user@domain..com',
      'user@',
      '',
      'user@@domain.com',
      'user@domain,com',
      'user@ domain.com',
      'user@domain. com',
      r'#@%^%#$@#$@#.map.net',
    ];

    for (final email in invalidEmails) {
      test('Invalid email rejection: "$email"', () {
        expect(emailRegex.hasMatch(email), isFalse);
      });
    }
  });

  group('Malaysian Phone Number Formatting Matrix (20 Cases)', () {
    final myPhoneRegex = RegExp(r'^(\+?6?01)[0-46-9]-*[0-9]{7,8}$');

    final validPhones = [
      '+60123456789',
      '+6012-3456789',
      '0123456789',
      '012-3456789',
      '+601112345678', // 8 digits for 011
      '011-12345678',
      '+60198765432',
      '019-8765432',
      '0173344556',
      '+60162233445',
    ];

    for (final phone in validPhones) {
      test('Valid Malaysian mobile phone format: $phone', () {
        expect(myPhoneRegex.hasMatch(phone), isTrue);
      });
    }

    final invalidPhones = [
      '123456', // Too short
      '+12025550143', // US format
      '+447911123456', // UK format
      '015-1234567', // 015 is VoIP not mobile
      '012-345', // Incomplete
      'abcdefghijk', // Letters
      '+6012-3456789012', // Too long
      '', // Empty
      '+60 12 345 6789', // Space format
      '012-3456-789', // Double dash
    ];

    for (final phone in invalidPhones) {
      test('Invalid phone rejection: "$phone"', () {
        expect(myPhoneRegex.hasMatch(phone), isFalse);
      });
    }
  });

  group('UserModel Profile Deserialization & Immutability Matrix (15 Cases)', () {
    for (int i = 1; i <= 15; i++) {
      test('UserModel deserialization and copyWith mutation iteration #$i', () {
        final mockMap = {
          'email': 'user_$i@urbangreen.my',
          'username': 'Botanist_$i',
          'photoUrl': 'https://storage.googleapis.com/avatars/user_$i.png',
          'createdAt': DateTime(2026, 1, i),
          'updatedAt': DateTime(2026, 2, i),
        };

        final user = UserModel.fromMap(mockMap, 'usr_id_$i');
        expect(user.uid, equals('usr_id_$i'));
        expect(user.email, equals('user_$i@urbangreen.my'));
        expect(user.username, equals('Botanist_$i'));
        expect(user.photoUrl, contains('user_$i.png'));
        expect(user.createdAt, equals(DateTime(2026, 1, i)));

        final updated = user.copyWith(
          username: 'Master_Botanist_$i',
          photoUrl: 'https://storage.googleapis.com/avatars/upgraded_$i.png',
        );

        expect(updated.username, equals('Master_Botanist_$i'));
        expect(updated.photoUrl, contains('upgraded_$i.png'));
        expect(updated.email, equals(user.email));
        expect(updated.uid, equals(user.uid));
      });
    }
  });
}
