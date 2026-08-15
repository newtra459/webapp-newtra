import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mjollnir_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:mjollnir_app/features/profile/data/models/profile_model.dart';
import 'package:mjollnir_app/features/profile/data/repositories/profile_repository.dart';

// ── Mock Repository ──────────────────────────────────────────────────────────

class MockProfileRepository implements ProfileRepository {
  ProfileModel? _stored;
  bool shouldThrow = false;

  @override
  Future<ProfileModel> getProfile() async {
    if (shouldThrow) throw Exception('Network error');
    return _stored ?? const ProfileModel(firstName: 'Test', lastName: 'User', email: 'test@example.com');
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    if (shouldThrow) throw Exception('Network error');
    _stored = profile;
    return profile;
  }

  @override
  Future<String> uploadProfileImage(File image) async {
    if (shouldThrow) throw Exception('Upload failed');
    return 'https://example.com/image.jpg';
  }

  @override
  Future<void> deleteProfileImage() async {
    if (shouldThrow) throw Exception('Delete failed');
  }

  @override
  ProfileModel? getCachedProfile() => _stored;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockProfileRepository mockRepo;
  late ProfileNotifier notifier;

  setUp(() {
    mockRepo = MockProfileRepository();
    notifier = ProfileNotifier(mockRepo);
  });

  group('ProfileNotifier', () {
    test('initializes with default ProfileData', () {
      expect(notifier.state.hasValue, isTrue);
      expect(notifier.state.value, isNotNull);
    });

    test('loadProfile updates state with fetched data', () async {
      await notifier.loadProfile();

      expect(notifier.state.value?.firstName, 'Test');
      expect(notifier.state.value?.lastName, 'User');
      expect(notifier.state.value?.email, 'test@example.com');
    });

    test('loadProfile keeps existing data on error', () async {
      // First load succeeds
      await notifier.loadProfile();
      expect(notifier.state.value?.firstName, 'Test');

      // Second load fails — should keep existing data
      mockRepo.shouldThrow = true;
      await notifier.loadProfile();
      expect(notifier.state.value?.firstName, 'Test');
      expect(notifier.state.hasError, isFalse);
    });

    test('updateProfile performs optimistic update and persists', () async {
      await notifier.loadProfile();
      final updated = notifier.state.value!.copyWith(firstName: 'Updated');

      final success = await notifier.updateProfile(updated);

      expect(success, isTrue);
      expect(notifier.state.value?.firstName, 'Updated');
    });

    test('updateProfile rolls back on failure', () async {
      await notifier.loadProfile();
      final original = notifier.state.value!;

      mockRepo.shouldThrow = true;
      final updated = original.copyWith(firstName: 'WillFail');
      final success = await notifier.updateProfile(updated);

      expect(success, isFalse);
      expect(notifier.state.value?.firstName, 'Test');
    });

    test('uploadProfileImage returns url and updates state', () async {
      await notifier.loadProfile();
      final fakeFile = File('/tmp/test_image.jpg');

      final url = await notifier.uploadProfileImage(fakeFile);

      expect(url, 'https://example.com/image.jpg');
      expect(notifier.state.value?.profileImageUrl, 'https://example.com/image.jpg');
    });

    test('uploadProfileImage returns null on failure', () async {
      await notifier.loadProfile();
      mockRepo.shouldThrow = true;

      final url = await notifier.uploadProfileImage(File('/tmp/test.jpg'));

      expect(url, isNull);
    });

    test('deleteProfileImage clears image fields on success', () async {
      await notifier.loadProfile();
      // Set an image first
      notifier.update(notifier.state.value!.copyWith(
        profileImageUrl: 'https://example.com/img.jpg',
        profileImagePath: '/path/to/img.jpg',
      ));

      final success = await notifier.deleteProfileImage();

      expect(success, isTrue);
      expect(notifier.state.value?.profileImageUrl, isNull);
      expect(notifier.state.value?.profileImagePath, isNull);
    });

    test('update directly sets state', () {
      const data = ProfileData(firstName: 'Direct', lastName: 'Set');
      notifier.update(data);

      expect(notifier.state.value?.firstName, 'Direct');
      expect(notifier.state.value?.lastName, 'Set');
    });
  });

  group('ProfileData', () {
    test('fullName combines first and last name', () {
      const data = ProfileData(firstName: 'John', lastName: 'Doe');
      expect(data.fullName, 'John Doe');
    });

    test('fullName trims when last name is empty', () {
      const data = ProfileData(firstName: 'John', lastName: '');
      expect(data.fullName, 'John');
    });

    test('initials returns first letters capitalized', () {
      const data = ProfileData(firstName: 'john', lastName: 'doe');
      expect(data.initials, 'JD');
    });

    test('initials handles empty names', () {
      const data = ProfileData(firstName: '', lastName: '');
      expect(data.initials, '');
    });

    test('copyWith preserves unchanged fields', () {
      const data = ProfileData(firstName: 'A', lastName: 'B', email: 'a@b.com');
      final updated = data.copyWith(firstName: 'X');

      expect(updated.firstName, 'X');
      expect(updated.lastName, 'B');
      expect(updated.email, 'a@b.com');
    });

    test('fromModel converts ProfileModel correctly', () {
      const model = ProfileModel(
        id: '123',
        firstName: 'Jane',
        lastName: 'Smith',
        email: 'jane@test.com',
        rating: 4.5,
        totalRatings: 50,
      );

      final data = ProfileData.fromModel(model);

      expect(data.id, '123');
      expect(data.firstName, 'Jane');
      expect(data.rating, 4.5);
      expect(data.totalRatings, 50);
    });

    test('toModel converts back correctly', () {
      const data = ProfileData(
        id: '456',
        firstName: 'Bob',
        lastName: 'Jones',
        rating: 3.5,
      );

      final model = data.toModel();

      expect(model.id, '456');
      expect(model.firstName, 'Bob');
      expect(model.rating, 3.5);
    });

    test('equality compares by id, firstName, lastName, email', () {
      const a = ProfileData(id: '1', firstName: 'A', lastName: 'B', email: 'x@y.com');
      const b = ProfileData(id: '1', firstName: 'A', lastName: 'B', email: 'x@y.com', phone: 'different');

      expect(a, equals(b));
    });
  });
}
