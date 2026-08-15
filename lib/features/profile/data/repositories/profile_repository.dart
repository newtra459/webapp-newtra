import 'dart:io';
import '../models/profile_model.dart';

/// Abstract contract for profile data access.
/// Backend team implements the remote data source; this interface stays stable.
abstract class ProfileRepository {
  /// Fetch the current user's profile.
  Future<ProfileModel> getProfile();

  /// Update profile fields.
  Future<ProfileModel> updateProfile(ProfileModel profile);

  /// Upload a profile image, returns the new image URL.
  Future<String> uploadProfileImage(File image);

  /// Delete the profile image.
  Future<void> deleteProfileImage();

  /// Get cached profile (offline support).
  ProfileModel? getCachedProfile();
}
