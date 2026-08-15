import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/local_storage.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;
  ProfileModel? _cachedProfile;

  static const String _cacheKey = 'cached_profile';

  ProfileRepositoryImpl(this._apiClient);

  @override
  Future<ProfileModel> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.profile.profile);
      final profile = ProfileModel.fromJson(response.data['data'] ?? response.data);
      _cachedProfile = profile;
      // Persist to local cache
      await LocalStorage.setString(_cacheKey, _encodeProfile(profile));
      return profile;
    } on AppError {
      // Fallback to cache on network failure
      final cached = getCachedProfile();
      if (cached != null) return cached;
      rethrow;
    } catch (e) {
      final cached = getCachedProfile();
      if (cached != null) return cached;
      throw GenericError('Failed to load profile: $e', originalError: e);
    }
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.user.update,
        data: profile.toJson(),
      );
      final updated = ProfileModel.fromJson(response.data['data'] ?? response.data);
      _cachedProfile = updated;
      await LocalStorage.setString(_cacheKey, _encodeProfile(updated));
      return updated;
    } catch (e) {
      if (e is AppError) rethrow;
      throw GenericError('Failed to update profile: $e', originalError: e);
    }
  }

  @override
  Future<String> uploadProfileImage(File image) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          image.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
      final response = await _apiClient.post(
        ApiEndpoints.profile.uploadImage,
        data: formData,
      );
      final imageUrl = response.data['data']?['url'] ?? response.data['url'] ?? '';
      if (_cachedProfile != null) {
        _cachedProfile = _cachedProfile!.copyWith(profileImageUrl: imageUrl);
        await LocalStorage.setString(_cacheKey, _encodeProfile(_cachedProfile!));
      }
      return imageUrl;
    } catch (e) {
      if (e is AppError) rethrow;
      throw FileError('Failed to upload image: $e', originalError: e);
    }
  }

  @override
  Future<void> deleteProfileImage() async {
    await _apiClient.delete(ApiEndpoints.profile.deleteImage);
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(profileImageUrl: null);
      await LocalStorage.setString(_cacheKey, _encodeProfile(_cachedProfile!));
    }
  }

  @override
  ProfileModel? getCachedProfile() {
    if (_cachedProfile != null) return _cachedProfile;
    final encoded = LocalStorage.getString(_cacheKey);
    if (encoded != null) {
      try {
        _cachedProfile = _decodeProfile(encoded);
        return _cachedProfile;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _encodeProfile(ProfileModel profile) {
    // Simple key=value encoding for SharedPreferences
    return '${profile.firstName}|${profile.lastName}|${profile.email}|'
        '${profile.phone}|${profile.bio}|${profile.dob}|${profile.city}|'
        '${profile.gender}|${profile.height}|${profile.weight}|'
        '${profile.rating}|${profile.totalRatings}|'
        '${profile.punctualityRating}|${profile.safetyRating}|'
        '${profile.friendlinessRating}|${profile.profileImageUrl ?? ''}|'
        '${profile.id ?? ''}';
  }

  ProfileModel _decodeProfile(String encoded) {
    final parts = encoded.split('|');
    if (parts.length < 17) throw const FormatException('Invalid cache');
    return ProfileModel(
      firstName: parts[0],
      lastName: parts[1],
      email: parts[2],
      phone: parts[3],
      bio: parts[4],
      dob: parts[5],
      city: parts[6],
      gender: parts[7],
      height: parts[8],
      weight: parts[9],
      rating: double.tryParse(parts[10]) ?? 0.0,
      totalRatings: int.tryParse(parts[11]) ?? 0,
      punctualityRating: double.tryParse(parts[12]) ?? 0.0,
      safetyRating: double.tryParse(parts[13]) ?? 0.0,
      friendlinessRating: double.tryParse(parts[14]) ?? 0.0,
      profileImageUrl: parts[15].isEmpty ? null : parts[15],
      id: parts[16].isEmpty ? null : parts[16],
    );
  }
}
