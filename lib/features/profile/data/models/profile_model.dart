const _profileModelUnset = Object();

class ProfileModel {
  final String? id;
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
  final String? profileImageUrl;
  final int points;

  const ProfileModel({
    this.id,
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
    this.rating = 0.0,
    this.totalRatings = 0,
    this.punctualityRating = 0.0,
    this.safetyRating = 0.0,
    this.friendlinessRating = 0.0,
    this.profileImageUrl,
    this.points = 0,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);

  ProfileModel copyWith({
    Object? id = _profileModelUnset,
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
    Object? profileImageUrl = _profileModelUnset,
    int? points,
  }) {
    return ProfileModel(
      id: identical(id, _profileModelUnset) ? this.id : id as String?,
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
      profileImageUrl: identical(profileImageUrl, _profileModelUnset)
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, firstName, lastName, email);
}

// Generated code placeholder — run `dart run build_runner build` to generate
// For now, manual fromJson/toJson implementation:

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
      id: json['uid'] as String? ?? json['id'] as String?,
      firstName: json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName: json['last_name'] as String? ?? json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      dob: json['date_of_birth'] as String? ?? json['dob'] as String? ?? '',
      city: json['city'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      height: json['height'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? json['totalRatings'] as int? ?? 0,
      punctualityRating: (json['punctuality_rating'] as num?)?.toDouble() ?? 0.0,
      safetyRating: (json['safety_rating'] as num?)?.toDouble() ?? 0.0,
      friendlinessRating: (json['friendliness_rating'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: json['avatar'] as String? ?? json['profile_image_url'] as String? ?? json['profileImageUrl'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'bio': instance.bio,
      'date_of_birth': instance.dob,
      'city': instance.city,
      'gender': instance.gender,
      'height': instance.height,
      'height_units': 'cm',
      'weight': instance.weight,
      'weight_units': 'kg',
      'avatar': instance.profileImageUrl ?? '',
    };
