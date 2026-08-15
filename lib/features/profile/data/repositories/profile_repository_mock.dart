// Dummy data mock — swap back to ProfileRepositoryImpl in profile_provider.dart
// when the backend /profile endpoint is live.

import 'dart:io';
import '../models/profile_model.dart';
import 'profile_repository.dart';

class ProfileRepositoryMock implements ProfileRepository {
  static final ProfileModel _profile = ProfileModel(
    id: 'mock-user-001',
    firstName: 'Rishwak',
    lastName: '',
    email: 'rishwak@iith.ac.in',
    phone: '+91 98765 43210',
    bio: 'Eco rider · CS PhD student · IIT Hyderabad 🚴',
    dob: '14 / 03 / 2000',
    city: 'Hyderabad',
    gender: 'Female',
    height: '163',
    weight: '58',
    rating: 4.8,
    totalRatings: 62,
    punctualityRating: 4.9,
    safetyRating: 4.7,
    friendlinessRating: 4.8,
  );

  ProfileModel _current = _profile;

  @override
  Future<ProfileModel> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _current;
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _current = profile;
    return _current;
  }

  @override
  Future<String> uploadProfileImage(File image) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    // Return a placeholder URL (no actual upload in mock)
    return 'https://ui-avatars.com/api/?name=Rishwak&background=6C63FF&color=fff&size=256';
  }

  @override
  Future<void> deleteProfileImage() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _current = ProfileModel(
      id: _current.id,
      firstName: _current.firstName,
      lastName: _current.lastName,
      email: _current.email,
      phone: _current.phone,
      bio: _current.bio,
      dob: _current.dob,
      city: _current.city,
      gender: _current.gender,
      height: _current.height,
      weight: _current.weight,
      rating: _current.rating,
      totalRatings: _current.totalRatings,
      punctualityRating: _current.punctualityRating,
      safetyRating: _current.safetyRating,
      friendlinessRating: _current.friendlinessRating,
    );
  }

  @override
  ProfileModel? getCachedProfile() => _current;
}
