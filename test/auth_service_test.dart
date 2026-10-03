import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/features/auth/domain/user_model.dart';
import 'package:sheride_user/core/constants/app_colors.dart';

void main() {
  group('SheRide User App - Phase 1 Unit Tests', () {
    test('UserModel serialization and deserialization works correctly', () {
      final user = UserModel(
        uid: 'test_uid_123',
        name: 'Priya Sharma',
        phone: '+919876543210',
        email: 'priya.sharma@example.com',
        gender: 'Female',
        profileImageUrl: 'https://example.com/avatar.jpg',
        emergencyContact: '+919876500000',
        role: 'user',
        isActive: true,
      );

      final map = user.toMap();
      expect(map['uid'], 'test_uid_123');
      expect(map['name'], 'Priya Sharma');
      expect(map['phone'], '+919876543210');
      expect(map['gender'], 'Female');
      expect(map['role'], 'user');
      expect(map['isActive'], true);

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.uid, user.uid);
      expect(reconstructed.name, user.name);
      expect(reconstructed.phone, user.phone);
      expect(reconstructed.gender, user.gender);
      expect(reconstructed.emergencyContact, user.emergencyContact);
    });

    test('Theme brand colors check', () {
      expect(AppColors.primary.toARGB32(), 0xFFE91E63);
      expect(AppColors.primaryLight.toARGB32(), 0xFFF8BBD0);
      expect(AppColors.secondary.toARGB32(), 0xFFAD1457);
    });

    test('User copyWith updates fields correctly', () {
      final user = UserModel(
        uid: 'uid_1',
        name: 'Initial Name',
        phone: '+911111111111',
      );

      final updated = user.copyWith(
        name: 'Updated Name',
        emergencyContact: '+919999999999',
      );

      expect(updated.name, 'Updated Name');
      expect(updated.emergencyContact, '+919999999999');
      expect(updated.uid, 'uid_1');
    });
  });
}
