import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;

  late String _selectedGender;
  bool _hasChanges = false;
  bool _isSaving = false;
  String? _profileImagePath;
  String? _profileImageUrl;
  String? _initialProfileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).valueOrNull ?? const ProfileData();
    _firstNameCtrl = TextEditingController(text: p.firstName);
    _lastNameCtrl = TextEditingController(text: p.lastName);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
    _bioCtrl = TextEditingController(text: p.bio);
    _dobCtrl = TextEditingController(text: p.dob);
    _cityCtrl = TextEditingController(text: p.city);
    _heightCtrl = TextEditingController(text: _normalizeHeightForDisplay(p.height));
    _weightCtrl = TextEditingController(text: p.weight);
    _selectedGender = p.gender;
    _profileImagePath = p.profileImagePath;
    _profileImageUrl = p.profileImageUrl;
    _initialProfileImageUrl = p.profileImageUrl;
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl,
      _phoneCtrl, _bioCtrl, _dobCtrl, _cityCtrl, _heightCtrl, _weightCtrl
    ]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final notifier = ref.read(profileProvider.notifier);
    final current = ref.read(profileProvider).valueOrNull ?? const ProfileData();

    try {
      var profileImageUrl = _profileImageUrl;
      final removedExistingImage = (_initialProfileImageUrl?.isNotEmpty ?? false) &&
          _profileImagePath == null &&
          _profileImageUrl == null;

      if (_profileImagePath != null) {
        profileImageUrl =
            await notifier.uploadProfileImage(File(_profileImagePath!));
        if (profileImageUrl == null || profileImageUrl.isEmpty) {
          throw Exception('Failed to upload profile photo');
        }
      } else if (removedExistingImage) {
        final deleted = await notifier.deleteProfileImage();
        if (!deleted) {
          throw Exception('Failed to remove profile photo');
        }
      }

      final updated = current.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        gender: _selectedGender,
        height: _normalizedHeightCm(),
        weight: _normalizedWeightKg(),
        profileImagePath: _profileImagePath,
        profileImageUrl: profileImageUrl,
      );

      final ok = await notifier.updateProfile(updated);
      if (!mounted) return;

      if (!ok) {
        throw Exception('Failed to save profile');
      }

      setState(() {
        _hasChanges = false;
        _profileImageUrl = profileImageUrl;
        _initialProfileImageUrl = profileImageUrl;
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _normalizeHeightForDisplay(String value) {
    final cm = _parseHeightInCm(value);
    if (cm == null || cm <= 0) {
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return cm.round().toString();
  }

  String _normalizedHeightCm() {
    final cm = _parseHeightInCm(_heightCtrl.text.trim());
    return cm == null || cm <= 0 ? '' : cm.round().toString();
  }

  String _normalizedWeightKg() {
    final digits = _weightCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }

  double? _parseHeightInCm(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final feetInches = RegExp(r"^(\d+)\s*'\s*(\d{1,2})?").firstMatch(trimmed);
    if (feetInches != null) {
      final feet = int.tryParse(feetInches.group(1) ?? '');
      final inches = int.tryParse(feetInches.group(2) ?? '0') ?? 0;
      if (feet != null) {
        return ((feet * 12) + inches) * 2.54;
      }
    }

    final dottedFeet = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(trimmed);
    if (dottedFeet != null) {
      final feet = int.tryParse(dottedFeet.group(1) ?? '');
      final inches = int.tryParse(dottedFeet.group(2) ?? '');
      if (feet != null && inches != null && feet >= 3 && feet <= 8 && inches < 12) {
        return ((feet * 12) + inches) * 2.54;
      }
    }

    final numeric = double.tryParse(trimmed.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (numeric == null) return null;
    if (numeric >= 100) return numeric;
    if (numeric >= 3 && numeric <= 8) return numeric * 30.48;
    return numeric;
  }

  Future<void> _pickImage() async {
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Choose Photo',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          color: AppColors.primary, size: 24.w),
                    ),
                    title: Text(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? photo = await _picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (photo != null) {
                        setState(() {
                          _profileImagePath = photo.path;
                          _profileImageUrl = null;
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.photo_library_rounded,
                          color: AppColors.success, size: 24.w),
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setState(() {
                          _profileImagePath = image.path;
                          _profileImageUrl = null;
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                  if (_profileImagePath != null || _profileImageUrl != null)
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 24.w),
                      ),
                      title: Text(
                        'Remove Photo',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _profileImagePath = null;
                          _profileImageUrl = null;
                          _hasChanges = true;
                        });
                      },
                    ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl,
      _phoneCtrl, _bioCtrl, _dobCtrl, _cityCtrl, _heightCtrl, _weightCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 28.h),
                  _buildAvatarSection(isDark),
                  SizedBox(height: 16.h),
                  _buildProfileSummaryCard(isDark),
                  SizedBox(height: 24.h),
                  _sectionHeader(
                    isDark: isDark,
                    icon: Icons.person_rounded,
                    title: 'Personal Info',
                    subtitle: 'Name and short bio',
                  ),
                  SizedBox(height: 12.h),
                  _buildCard(isDark, [
                    _buildField(
                      isDark: isDark,
                      icon: Icons.person_rounded,
                      label: 'First Name',
                      controller: _firstNameCtrl,
                    ),
                    _divider(isDark),
                    _buildField(
                      isDark: isDark,
                      icon: Icons.person_outline_rounded,
                      label: 'Last Name',
                      controller: _lastNameCtrl,
                    ),
                    _divider(isDark),
                    _buildBioField(isDark),
                  ]),
                  SizedBox(height: 24.h),
                  _sectionHeader(
                    isDark: isDark,
                    icon: Icons.call_outlined,
                    title: 'Contact',
                    subtitle: 'How people can reach you',
                  ),
                  SizedBox(height: 12.h),
                  _buildCard(isDark, [
                    _buildField(
                      isDark: isDark,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      controller: _emailCtrl,
                      type: TextInputType.emailAddress,
                    ),
                    _divider(isDark),
                    _buildField(
                      isDark: isDark,
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      controller: _phoneCtrl,
                      type: TextInputType.phone,
                    ),
                    _divider(isDark),
                    _buildField(
                      isDark: isDark,
                      icon: Icons.location_on_outlined,
                      label: 'City',
                      controller: _cityCtrl,
                    ),
                  ]),
                  SizedBox(height: 24.h),
                  _sectionHeader(
                    isDark: isDark,
                    icon: Icons.badge_outlined,
                    title: 'About You',
                    subtitle: 'Personal details',
                  ),
                  SizedBox(height: 12.h),
                  _buildCard(isDark, [
                    _buildField(
                      isDark: isDark,
                      icon: Icons.cake_outlined,
                      label: 'Date of Birth',
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(context),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18.w, color: AppColors.grey400),
                    ),
                    _divider(isDark),
                    _buildGenderRow(isDark),
                  ]),
                  SizedBox(height: 24.h),
                  _sectionHeader(
                    isDark: isDark,
                    icon: Icons.monitor_weight_outlined,
                    title: 'Body Metrics',
                    subtitle: 'Used for analytics and goals',
                  ),
                  SizedBox(height: 12.h),
                  _buildCard(isDark, [
                    _buildMetricRow(isDark),
                  ]),
                  SizedBox(height: 32.h),
                  _buildSaveButton(context, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F1721), AppColors.darkSurface]
                : [const Color(0xFFE9F7F2), AppColors.grey50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16.w,
              color: isDark ? AppColors.white : AppColors.grey800),
        ),
      ),
      title: Text(
        'Edit Profile',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.white : AppColors.grey900,
        ),
      ),
      centerTitle: true,
      actions: [
        AnimatedOpacity(
          opacity: (_hasChanges && !_isSaving) ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: _hasChanges && !_isSaving
                ? () {
                    HapticFeedback.lightImpact();
                    _saveProfile();
                  }
                : null,
            child: Container(
              margin: EdgeInsets.only(right: 16.w, top: 10.h, bottom: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatarSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                // Gradient ring
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.all(3.w),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.darkCard : AppColors.grey100,
                    ),
                    alignment: Alignment.center,
                    child: _profileImagePath != null
                        ? ClipOval(
                            child: Image.file(
                              File(_profileImagePath!),
                              width: 94.w,
                              height: 94.w,
                              fit: BoxFit.cover,
                            ),
                          )
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  _profileImageUrl!,
                                  width: 94.w,
                                  height: 94.w,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              )
                        : Consumer(
                            builder: (_, ref, __) {
                              final p = ref.watch(profileProvider).valueOrNull ?? const ProfileData();
                              return Text(
                                p.initials.isNotEmpty ? p.initials : 'SR',
                                style: TextStyle(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 2.h,
                  right: 2.w,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurface : AppColors.grey50,
                        width: 2.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child:
                        Icon(Icons.camera_alt_rounded, size: 14.w, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Tap to change photo',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  Widget _buildProfileSummaryCard(bool isDark) {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final displayName = ([first, last]..removeWhere((e) => e.isEmpty)).join(' ');
    final title = displayName.isEmpty ? 'Your Profile' : displayName;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2430), const Color(0xFF111922)]
              : [const Color(0xFFF2FBF7), const Color(0xFFE7F6EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.tune_rounded, color: AppColors.primary, size: 21.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Keep details up-to-date for better ride insights.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16.w, color: AppColors.primary),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52.w,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  // ── Field widgets ─────────────────────────────────────────────────────────

  Widget _buildField({
    required bool isDark,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType type = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  TextField(
                    controller: controller,
                    readOnly: readOnly,
                    onTap: onTap,
                    keyboardType: type,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    cursorColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBioField(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.edit_note_rounded, size: 17.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bio',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey500,
                  ),
                ),
                SizedBox(height: 2.h),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 2,
                  maxLength: 80,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    counterStyle:
                        TextStyle(fontSize: 10.sp, color: AppColors.grey400),
                  ),
                  cursorColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRow(bool isDark) {
    const genders = ['Male', 'Female', 'Other'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.wc_rounded, size: 17.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey500,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: genders.map((g) {
                    final selected = _selectedGender == g;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedGender = g;
                        _hasChanges = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: 8.w),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 7.h),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkElevated
                                  : AppColors.grey100),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.white
                                : (isDark
                                    ? AppColors.grey400
                                    : AppColors.grey600),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        children: [
          // Height
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.height_rounded, size: 16.w, color: AppColors.primary),
                    SizedBox(width: 6.w),
                    Text('Height',
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey500)),
                  ],
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.grey50,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.white : AppColors.grey900,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          cursorColor: AppColors.primary,
                        ),
                      ),
                      Text('cm',
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Weight
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_weight_outlined, size: 16.w, color: AppColors.primary),
                    SizedBox(width: 6.w),
                    Text('Weight',
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey500)),
                  ],
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.grey50,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.white : AppColors.grey900,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          cursorColor: AppColors.primary,
                        ),
                      ),
                      Text('kg',
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: _isSaving
          ? null
          : () {
        HapticFeedback.lightImpact();
        _saveProfile();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isSaving
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 3, 14),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Theme.of(ctx).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      setState(() => _hasChanges = true);
    }
  }
}
