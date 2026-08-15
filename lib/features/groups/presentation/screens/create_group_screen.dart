import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_text_field.dart';
import '../providers/groups_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  String _selectedCategory = 'Campus';
  bool _isPrivate = false;
  String? _groupImagePath;
  final ImagePicker _picker = ImagePicker();

  static const _categories = [
    ('Campus',     Icons.school_rounded,           AppColors.primary),
    ('Eco',        Icons.eco_rounded,              AppColors.success),
    ('Racing',     Icons.speed_rounded,            AppColors.calories),
    ('Leisure',    Icons.weekend_rounded,          AppColors.elevation),
    ('E-Bike',     Icons.electric_bike_rounded,    AppColors.speed),
    ('University', Icons.account_balance_rounded,  AppColors.info),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color get _accent {
    return _categories
        .firstWhere((c) => c.$1 == _selectedCategory,
            orElse: () => _categories.first)
        .$3;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.grey50,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              _buildHeader(context, isDark),

              // ── Scrollable body ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar picker
                      _buildAvatarPicker(isDark),
                      SizedBox(height: 28.h),

                      // Group Name
                      _label('Group Name', isDark),
                      SizedBox(height: 8.h),
                      MjTextField(
                        hint: 'e.g. Campus Cyclists',
                        controller: _nameCtrl,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                        prefix: Icon(Icons.group_rounded,
                            size: 18.w, color: AppColors.grey400),
                      ),
                      SizedBox(height: 20.h),

                      // Description
                      _label('Description', isDark),
                      SizedBox(height: 8.h),
                      MjTextField(
                        hint: 'What is this group about?',
                        controller: _descCtrl,
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Description is required'
                            : null,
                        prefix: Icon(Icons.notes_rounded,
                            size: 18.w, color: AppColors.grey400),
                      ),
                      SizedBox(height: 24.h),

                      // Category
                      _label('Category', isDark),
                      SizedBox(height: 12.h),
                      _buildCategoryPicker(isDark),
                      SizedBox(height: 24.h),

                      // Privacy toggle
                      _buildPrivacyRow(isDark),
                      SizedBox(height: 36.h),

                      // Create button
                      _buildCreateButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 16.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.grey100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16.w,
                  color: isDark ? AppColors.white : AppColors.grey800),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Group',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                Text(
                  'Build your riding community',
                  style:
                      TextStyle(fontSize: 12.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar picker ──────────────────────────────────────────────────────────

  Widget _buildAvatarPicker(bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: _pickGroupImage,
        child: Column(
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: 0.12),
                    border: Border.all(color: _accent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _groupImagePath != null
                      ? ClipOval(
                          child: Image.file(
                            File(_groupImagePath!),
                            width: 96.w,
                            height: 96.w,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          _categories
                              .firstWhere((c) => c.$1 == _selectedCategory,
                                  orElse: () => _categories.first)
                              .$2,
                          size: 42.w,
                          color: _accent,
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.white,
                          width: 2),
                    ),
                    child: Icon(Icons.camera_alt_rounded,
                        size: 14.w, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap to add photo',
              style: TextStyle(
                  fontSize: 12.sp, color: AppColors.grey500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category picker ────────────────────────────────────────────────────────

  Widget _buildCategoryPicker(bool isDark) {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: _categories.map((cat) {
        final (label, icon, color) = cat;
        final sel = _selectedCategory == label;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: sel
                  ? color.withValues(alpha: 0.14)
                  : (isDark ? AppColors.darkCard : AppColors.white),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: sel ? color : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15.w,
                    color: sel ? color : AppColors.grey500),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? color : AppColors.grey500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Privacy toggle ─────────────────────────────────────────────────────────

  Widget _buildPrivacyRow(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _isPrivate
                  ? AppColors.warning.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
              size: 20.w,
              color: _isPrivate ? AppColors.warning : AppColors.primary,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? 'Private Group' : 'Public Group',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _isPrivate
                      ? 'Only invited members can join'
                      : 'Anyone can find and join this group',
                  style: TextStyle(
                      fontSize: 12.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
            activeTrackColor: AppColors.warning,
            inactiveTrackColor:
                AppColors.primary.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  // ── Create button ─────────────────────────────────────────────────────────

  bool _isCreating = false;

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isCreating ? null : () async {
        if (_formKey.currentState!.validate()) {
          setState(() => _isCreating = true);
          try {
            final repo = ref.read(groupRepositoryProvider);
            await repo.createGroup(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              category: _selectedCategory,
              visibility: _isPrivate ? 'private' : 'public',
              groupImage: _groupImagePath,
            );
            ref.read(groupsProvider.notifier).loadGroups();
            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create group: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isCreating = false);
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.38),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_rounded, color: Colors.white, size: 20.w),
            SizedBox(width: 10.w),
            Text(
              _isCreating ? 'Creating...' : 'Create Group',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.grey200 : AppColors.grey800,
      ),
    );
  }

  // ── Image picker ───────────────────────────────────────────────────────────

  Future<void> _pickGroupImage() async {
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
                    'Add Group Photo',
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
                          _groupImagePath = photo.path;
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
                          _groupImagePath = image.path;
                        });
                      }
                    },
                  ),
                  if (_groupImagePath != null)
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
                          _groupImagePath = null;
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
}

