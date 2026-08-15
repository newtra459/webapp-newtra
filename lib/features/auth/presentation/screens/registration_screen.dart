import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_state_provider.dart';
import '../providers/auth_provider.dart';
import '../../data/models/auth_user_model.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/mj_button.dart';
import '../../../../core/widgets/mj_text_field.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());

  // Step 1
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _dob;
  String? _gender;

  // Step 2
  final _emailController = TextEditingController();
  double _height = 170;
  double _weight = 65;
  bool _isMetric = false;
  String? _userType;
  String? _organization;
  String? _campusRole; // 'Student' or 'Staff' — shown when a college is selected
  final _idController = TextEditingController();

  // Step 3
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _country;

  // Other
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  XFile? _avatarFile;
  final _picker = ImagePicker();

  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  final List<String> _userTypes = ['University', 'Corporate', 'General'];
  final List<String> _colleges = [
    'IIT Hyderabad',
    'IIT Bombay',
    'IIT Delhi',
    'IIT Madras',
    'BITS Pilani',
    'NIT Warangal',
    'Other',
  ];
  final List<String> _companies = [
    'TCS',
    'Infosys',
    'Wipro',
    'HCL',
    'Tech Mahindra',
    'Other',
  ];
  final List<String> _countries = ['India', 'United States', 'United Kingdom', 'Other'];

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKeys[_currentStep].currentState!.validate()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeRegistration();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatHeightLabel() {
    if (_isMetric) {
      return '${_height.round()} cm';
    }

    final totalInches = (_height / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet.$inches ft';
  }

  void _completeRegistration() async {
    setState(() => _isLoading = true);

    final authState = ref.read(authFormProvider);
    final phone = authState.phone;

    // Calculate age from DOB
    String age = '';
    if (_dob != null) {
      age = (DateTime.now().year - _dob!.year).toString();
    }

    final user = AuthUserModel(
      phone: phone,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      dateOfBirth: _dob != null
          ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : '',
      age: age,
      gender: _gender ?? '',
      userType: _userType ?? 'General',
      organization: _organization ?? '',
      organizationId: _idController.text.trim(),
      weight: _weight.round().toString(),
      height: _height.round().toString(),
      weightUnits: 'kg',
      heightUnits: 'cm',
      addressLine: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      country: _country ?? 'India',
      inviteCode: _inviteCodeController.text.trim(),
    );

    final success = await ref.read(authFormProvider.notifier).register(user);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final token = LocalStorage.getToken() ?? '';
      if (token.isNotEmpty) {
        await ref.read(authStateProvider.notifier).setAuthenticated(token);
      }
      await ref.read(authStateProvider.notifier).setRegistrationComplete();

      // Save local prefs
      if (_userType != null) await LocalStorage.saveUserType(_userType!);
      if (_organization != null) await LocalStorage.saveOrganization(_organization!);
      if (_campusRole != null) await LocalStorage.saveCampusRole(_campusRole!);

      if (mounted) context.go('/home');
    } else {
      final error = ref.read(authFormProvider).error;
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        ref.read(authFormProvider.notifier).clearError();
      }
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file != null) setState(() => _avatarFile = file);
  }

  Future<void> _selectDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _dob = date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildStepRail(isDark),
            SizedBox(height: 4.h),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(isDark),
                  _buildStep2(isDark),
                  _buildStep3(isDark),
                ],
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 24.w, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20.w,
                  color: isDark ? AppColors.white : AppColors.grey900),
              onPressed: _prevStep,
            )
          else
            SizedBox(width: 48.w),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'Step ${_currentStep + 1} of 3',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRail(bool isDark) {
    const icons = [
      Icons.person_outline_rounded,
      Icons.badge_outlined,
      Icons.location_on_outlined,
    ];
    const labels = ['Personal', 'Identity', 'Address'];
    const headings = [
      'Tell us about you',
      'Work & Identity',
      'Where are you?',
    ];
    const subtitles = [
      'Fill in your basic personal information',
      'Your organisation and measurements',
      'Your home address for better service',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (i) {
              final done = i < _currentStep;
              final active = i == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (done || active)
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkElevated
                                : AppColors.grey100),
                      ),
                      child: Center(
                        child: done
                            ? Icon(Icons.check_rounded,
                                size: 18.w, color: Colors.white)
                            : Icon(icons[i],
                                size: 16.w,
                                color: active
                                    ? Colors.white
                                    : AppColors.grey500),
                      ),
                    ),
                    if (i < 2)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 2.h,
                          color: i < _currentStep
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkElevated
                                  : AppColors.grey200),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: 8.h),
          Row(
            children: List.generate(3, (i) {
              final active = i == _currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8.w : 0),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                      color:
                          active ? AppColors.primary : AppColors.grey500,
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 20.h),
          Text(
            headings[_currentStep],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.white : AppColors.grey900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitles[_currentStep],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkCard : AppColors.grey100,
          ),
        ),
      ),
      child: MjButton(
        text: _currentStep == 2 ? 'Complete Setup' : 'Continue',
        isLoading: _isLoading,
        onPressed: _nextStep,
      ),
    );
  }

  Widget _buildStep1(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),

            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: _avatarFile != null
                          ? ClipOval(
                              child: Image.file(
                                File(_avatarFile!.path),
                                fit: BoxFit.cover,
                                width: 80.w,
                                height: 80.w,
                              ),
                            )
                          : Icon(Icons.person_rounded,
                              size: 40.w, color: AppColors.primary),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 14.w, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            Row(
              children: [
                Expanded(
                  child: MjTextField(
                    label: 'First Name',
                    hint: 'First',
                    controller: _firstNameController,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: MjTextField(
                    label: 'Last Name',
                    hint: 'Last',
                    controller: _lastNameController,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            MjTextField(
              label: 'Date of Birth',
              hint: 'Select date of birth',
              readOnly: true,
              onTap: _selectDob,
              controller: TextEditingController(
                text: _dob != null
                    ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                    : '',
              ),
              suffix: Icon(Icons.calendar_today_outlined,
                  size: 18.w, color: AppColors.grey500),
              validator: (_) =>
                  _dob == null ? 'Date of birth is required' : null,
            ),
            SizedBox(height: 20.h),

            Text(
              'Gender',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.grey700),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _genderOptions.map((g) {
                final sel = _gender == g;
                return _SelectChip(
                  label: g,
                  selected: sel,
                  onTap: () => setState(() => _gender = sel ? null : g),
                  isDark: isDark,
                );
              }).toList(),
            ),

            SizedBox(height: 36.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),

            MjTextField(
              label: 'Email Address',
              hint: 'your@email.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(v)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            SizedBox(height: 20.h),

            // Measurements card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.grey50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkElevated : AppColors.grey200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.straighten_outlined,
                          size: 16.w, color: AppColors.primary),
                      SizedBox(width: 6.w),
                      Text(
                        'Measurements',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.white
                              : AppColors.grey800,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _isMetric = !_isMetric),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            _isMetric ? 'cm / kg' : 'ft / kg',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildSliderRow(
                    label: 'Height',
                    value: _formatHeightLabel(),
                    sliderValue: _height,
                    min: 120,
                    max: 220,
                    onChanged: (v) => setState(() => _height = v),
                    isDark: isDark,
                  ),
                  SizedBox(height: 12.h),
                  _buildSliderRow(
                    label: 'Weight',
                    value: '${_weight.round()} kg',
                    sliderValue: _weight,
                    min: 30,
                    max: 200,
                    onChanged: (v) => setState(() => _weight = v),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            Text(
              'User Type',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.grey700),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _userTypes.map((type) {
                final sel = _userType == type;
                return _SelectChip(
                  label: type,
                  selected: sel,
                  onTap: () => setState(() {
                    _userType = sel ? null : type;
                    _organization = null;
                    _campusRole = null;
                  }),
                  isDark: isDark,
                );
              }).toList(),
            ),

            if (_userType == 'University' || _userType == 'Corporate') ...[
              SizedBox(height: 20.h),
              Text(
                _userType == 'University' ? 'College' : 'Company',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.grey700),
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: _organization,
                items: (_userType == 'University' ? _colleges : _companies)
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _organization = v;
                  _campusRole = null;
                }),
                decoration:
                    const InputDecoration(hintText: 'Select organisation'),
              ),

              if (_userType == 'University') ...[
                SizedBox(height: 20.h),
                Text(
                  'Role at Campus',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppColors.white : AppColors.grey700),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: ['Student', 'Staff'].map((role) {
                    final sel = _campusRole == role;
                    return Padding(
                      padding: EdgeInsets.only(right: 10.w),
                      child: _SelectChip(
                        label: role,
                        icon: role == 'Student'
                            ? Icons.school_outlined
                            : Icons.badge_outlined,
                        selected: sel,
                        onTap: () => setState(
                            () => _campusRole = sel ? null : role),
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                ),
              ],

              SizedBox(height: 16.h),
              MjTextField(
                label: _userType == 'University'
                    ? 'Student/Staff ID'
                    : 'Employee ID',
                hint: 'Enter your ID',
                controller: _idController,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ID is required' : null,
              ),
            ],

            if (_userType == 'General') ...[
              SizedBox(height: 16.h),
              MjTextField(
                label: 'Place Name',
                hint: 'Enter your place/city',
                controller: _idController,
                textInputAction: TextInputAction.next,                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Place name is required' : null,              ),
            ],

            SizedBox(height: 36.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String value,
    required double sliderValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: 12.sp, color: AppColors.grey500)),
            ),
            SizedBox(width: 10.w),
            Text(value,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor:
                AppColors.primary.withValues(alpha: 0.15),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: sliderValue,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),

            MjTextField(
              label: 'Address Line',
              hint: 'Street address',
              controller: _addressController,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Address is required' : null,
            ),
            SizedBox(height: 16.h),

            Row(
              children: [
                Expanded(
                  child: MjTextField(
                    label: 'City',
                    hint: 'City',
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: MjTextField(
                    label: 'State',
                    hint: 'State',
                    controller: _stateController,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            Row(
              children: [
                Expanded(
                  child: MjTextField(
                    label: 'Pincode',
                    hint: '6-digit pincode',
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 6) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Country',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.white
                                : AppColors.grey700),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        value: _country,
                        isExpanded: true,
                        items: _countries
                            .map((e) => DropdownMenuItem(
                                value: e, 
                                child: Text(
                                  e,
                                  overflow: TextOverflow.ellipsis,
                                )))
                            .toList(),
                        onChanged: (v) => setState(() => _country = v),
                        decoration:
                            const InputDecoration(hintText: 'Select'),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            MjTextField(
              label: 'Invite Code (Optional)',
              hint: 'Have an invite code? Enter here',
              controller: _inviteCodeController,
              textInputAction: TextInputAction.done,
            ),

            SizedBox(height: 36.h),
          ],
        ),
      ),
    );
  }
}

// ── Custom selection chip ─────────────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _SelectChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? AppColors.darkElevated : AppColors.grey50),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.grey700 : AppColors.grey200),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14.w,
                  color:
                      selected ? AppColors.primary : AppColors.grey500),
              SizedBox(width: 5.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppColors.primary
                    : (isDark ? AppColors.grey300 : AppColors.grey600),
              ),
            ),
            if (selected) ...[
              SizedBox(width: 5.w),
              Icon(Icons.check_circle_rounded,
                  size: 14.w, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
