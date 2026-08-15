import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../../../core/network/providers.dart';

const _profileDataUnset = Object();

// ── Providers ───────────────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(apiClientProvider));
});

/// Main profile state provider with full async support
final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileData>>((ref) {
      return ProfileNotifier(ref.watch(profileRepositoryProvider));
    });

// ── ProfileData ──────────────────────────────────────────────────────────────
// Presentation-layer data class consumed by widgets.
// Maps to/from ProfileModel (data layer) to keep layers decoupled.

class ProfileData {
  final String id;

  /// The app-assigned unique user ID, e.g. "MJL-A1B2C3D4".
  final String userNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String bio;
  final String dob;
  final String city;
  final String gender;
  final String height;
  final String weight;
  final double rating;
  final int totalRatings;
  final double punctualityRating;
  final double safetyRating;
  final double friendlinessRating;
  final String? profileImagePath;
  final String? profileImageUrl;
  final int points;

  const ProfileData({
    this.id = '',
    this.userNumber = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.bio = '',
    this.dob = '',
    this.city = '',
    this.gender = '',
    this.height = '',
    this.weight = '',
    this.rating = 0,
    this.totalRatings = 0,
    this.punctualityRating = 0,
    this.safetyRating = 0,
    this.friendlinessRating = 0,
    this.profileImagePath,
    this.profileImageUrl,
    this.points = 0,
  });

  ProfileData copyWith({
    String? id,
    String? userNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? bio,
    String? dob,
    String? city,
    String? gender,
    String? height,
    String? weight,
    double? rating,
    int? totalRatings,
    double? punctualityRating,
    double? safetyRating,
    double? friendlinessRating,
    Object? profileImagePath = _profileDataUnset,
    Object? profileImageUrl = _profileDataUnset,
    int? points,
  }) {
    return ProfileData(
      id: id ?? this.id,
      userNumber: userNumber ?? this.userNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      dob: dob ?? this.dob,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      punctualityRating: punctualityRating ?? this.punctualityRating,
      safetyRating: safetyRating ?? this.safetyRating,
      friendlinessRating: friendlinessRating ?? this.friendlinessRating,
      profileImagePath: identical(profileImagePath, _profileDataUnset)
          ? this.profileImagePath
          : profileImagePath as String?,
      profileImageUrl: identical(profileImageUrl, _profileDataUnset)
          ? this.profileImageUrl
          : profileImageUrl as String?,
      points: points ?? this.points,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  /// Convert from data model to presentation model
  factory ProfileData.fromModel(ProfileModel model) {
    return ProfileData(
      id: model.id ?? '',
      userNumber: model.id ?? '',
      firstName: model.firstName,
      lastName: model.lastName,
      email: model.email,
      phone: model.phone,
      bio: model.bio,
      dob: model.dob,
      city: model.city,
      gender: model.gender,
      height: model.height,
      weight: model.weight,
      rating: model.rating,
      totalRatings: model.totalRatings,
      punctualityRating: model.punctualityRating,
      safetyRating: model.safetyRating,
      friendlinessRating: model.friendlinessRating,
      profileImageUrl: model.profileImageUrl,
      points: model.points,
    );
  }

  /// Convert to data model for API calls
  ProfileModel toModel() {
    return ProfileModel(
      id: id.isEmpty ? null : id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      bio: bio,
      dob: dob,
      city: city,
      gender: gender,
      height: height,
      weight: weight,
      rating: rating,
      totalRatings: totalRatings,
      punctualityRating: punctualityRating,
      safetyRating: safetyRating,
      friendlinessRating: friendlinessRating,
      profileImageUrl: profileImageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, firstName, lastName, email);
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileData>> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository)
    : super(const AsyncValue.data(ProfileData())) {
    // Try loading from cache immediately, then refresh from API
    _loadCached();
    loadProfile();
  }

  void _loadCached() {
    final cached = _repository.getCachedProfile();
    if (cached != null) {
      state = AsyncValue.data(ProfileData.fromModel(cached));
    }
  }

  /// Fetch profile from the backend
  Future<void> loadProfile() async {
    // Don't show loading if we already have data (silent refresh)
    final hasData = state.hasValue;
    if (!hasData) {
      state = const AsyncValue.loading();
    }

    try {
      final model = await _repository.getProfile();
      state = AsyncValue.data(ProfileData.fromModel(model));
    } catch (e, st) {
      // Keep existing data on error if available
      if (hasData) {
        state = AsyncValue.data(state.value!);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Update profile fields via API
  Future<bool> updateProfile(ProfileData data) async {
    final previous = state;
    // Optimistic update
    state = AsyncValue.data(data);

    try {
      final updated = await _repository.updateProfile(data.toModel());
      state = AsyncValue.data(ProfileData.fromModel(updated));
      return true;
    } catch (e) {
      // Rollback on failure
      state = previous;
      return false;
    }
  }

  /// Upload profile image
  Future<String?> uploadProfileImage(File image) async {
    try {
      final url = await _repository.uploadProfileImage(image);
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(
            profileImageUrl: url,
            profileImagePath: image.path,
          ),
        );
      }
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Remove profile image
  Future<bool> deleteProfileImage() async {
    try {
      await _repository.deleteProfileImage();
      if (state.hasValue) {
        final current = state.value!;
        state = AsyncValue.data(
          current.copyWith(profileImageUrl: null, profileImagePath: null),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Direct local update (for when backend isn't needed)
  void update(ProfileData data) => state = AsyncValue.data(data);
}
