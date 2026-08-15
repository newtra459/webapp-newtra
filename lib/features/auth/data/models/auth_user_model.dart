class AuthUserModel {
  final String id;
  /// Human-readable app user ID, e.g. "MJL-A1B2C3D4".
  /// Populated from the server's `user_number` field or derived from [id].
  final String userNumber;
  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final String userType;
  final String? organization;
  final String? organizationId;
  final String? dateOfBirth;
  final String? age;
  final String? gender;
  final String? weight;
  final String? height;
  final String? weightUnits;
  final String? heightUnits;
  final String? addressLine;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final String? inviteCode;

  const AuthUserModel({
    this.id = '',
    this.userNumber = '',
    this.phone = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.userType = 'General User',
    this.organization,
    this.organizationId,
    this.dateOfBirth,
    this.age,
    this.gender,
    this.weight,
    this.height,
    this.weightUnits,
    this.heightUnits,
    this.addressLine,
    this.city,
    this.state,
    this.pincode,
    this.country,
    this.inviteCode,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final id = json['uid'] as String? ?? json['id'] as String? ?? '';
    final rawNumber = json['user_number'] as String? ?? json['userNumber'] as String?;
    final userNumber = rawNumber?.isNotEmpty == true
        ? rawNumber!
        : (id.isNotEmpty ? 'MJL-${id.substring(0, id.length.clamp(0, 8)).toUpperCase()}' : '');
    return AuthUserModel(
      id: id,
      userNumber: userNumber,
      phone: json['phone'] as String? ?? '',
      firstName: json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName: json['last_name'] as String? ?? json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userType: json['type'] as String? ?? json['user_type'] as String? ?? json['userType'] as String? ?? 'General User',
      organization: json['organization'] as String?,
      organizationId: json['organization_id'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      age: json['age'] as String?,
      gender: json['gender'] as String?,
      weight: json['weight'] as String?,
      height: json['height'] as String?,
      weightUnits: json['weight_units'] as String?,
      heightUnits: json['height_units'] as String?,
      addressLine: json['address_line'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      country: json['country'] as String?,
      inviteCode: json['invite_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'type': userType,
        'organization': organization ?? '',
        'organization_id': organizationId ?? '',
        'date_of_birth': dateOfBirth ?? '',
        'age': age ?? '',
        'gender': gender ?? '',
        'weight': weight ?? '',
        'height': height ?? '',
        'weight_units': weightUnits ?? 'kg',
        'height_units': heightUnits ?? 'cm',
        'address_line': addressLine ?? '',
        'city': city ?? '',
        'state': state ?? '',
        'pincode': pincode ?? '',
        'country': country ?? '',
        'invite_code': inviteCode ?? '',
      };
}
