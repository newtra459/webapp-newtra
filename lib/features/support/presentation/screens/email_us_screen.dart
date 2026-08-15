import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_button.dart';
import '../../../../core/widgets/mj_text_field.dart';
import '../../data/models/support_model.dart';
import '../providers/support_provider.dart';

class EmailUsScreen extends ConsumerStatefulWidget {
  const EmailUsScreen({super.key});

  @override
  ConsumerState<EmailUsScreen> createState() => _EmailUsScreenState();
}

class _EmailUsScreenState extends ConsumerState<EmailUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  String? _selectedCategory;
  final List<String> _categories = [
    'General Inquiry',
    'Technical Support',
    'Billing & Payments',
    'Subscription Issue',
    'Vehicle Problem',
    'Feature Request',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ticket = SupportTicket(
        id: '',
        category: _selectedCategory ?? 'general',
        subject: _subjectController.text.trim(),
        description: [
          'Subject: ${_subjectController.text.trim()}',
          'From: ${_nameController.text.trim()}',
          'Email: ${_emailController.text.trim()}',
          '',
          _messageController.text.trim(),
        ].join('\n'),
        createdAt: DateTime.now(),
      );

      await ref.read(supportRepositoryProvider).createTicket(ticket);
      if (!mounted) return;
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28.w),
              SizedBox(width: 12.w),
              const Text('Email Sent!'),
            ],
          ),
          content: const Text(
            'Your support ticket has been created. We\'ll get back to you within 24 hours.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create support ticket: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      appBar: AppBar(
        title: const Text('Email Us'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.email_rounded,
                        color: Colors.white,
                        size: 24.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get in Touch',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.grey900,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'We typically respond within 24 hours',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.grey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Name field
              MjTextField(
                label: 'Full Name',
                hint: 'Enter your name',
                controller: _nameController,
                prefix: const Icon(Icons.person_outline_rounded),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              SizedBox(height: 16.h),

              // Email field
              MjTextField(
                label: 'Email Address',
                hint: 'your.email@example.com',
                controller: _emailController,
                prefix: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              // Category dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.white : AppColors.grey700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select a category'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.category_outlined,
                        color: AppColors.grey500,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.grey700 : AppColors.grey200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.grey700 : AppColors.grey200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    items: _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                    validator: (v) =>
                        v == null ? 'Please select a category' : null,
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Subject field
              MjTextField(
                label: 'Subject',
                hint: 'Brief description of your inquiry',
                controller: _subjectController,
                prefix: const Icon(Icons.subject_rounded),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Subject is required' : null,
              ),
              SizedBox(height: 16.h),

              // Message field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.white : AppColors.grey700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 6,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Describe your issue or inquiry in detail...',
                      hintStyle: TextStyle(
                        color: AppColors.grey400,
                        fontSize: 13.sp,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.grey700 : AppColors.grey200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.grey700 : AppColors.grey200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Message is required';
                      }
                      if (v.length < 10) {
                        return 'Message must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Contact info
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.grey100,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.w,
                          color: AppColors.info,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Other Ways to Reach Us',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.white : AppColors.grey900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    _buildContactRow(
                      Icons.phone_rounded,
                      'Helpline',
                      '1800-XXX-XXXX',
                      isDark,
                    ),
                    SizedBox(height: 6.h),
                    _buildContactRow(
                      Icons.email_rounded,
                      'Email',
                      'support@newtra.app',
                      isDark,
                    ),
                    SizedBox(height: 6.h),
                    _buildContactRow(
                      Icons.schedule_rounded,
                      'Support Hours',
                      'Mon-Sat, 9 AM - 6 PM',
                      isDark,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),

              // Send button
              MjButton(
                text: 'Send Message',
                isLoading: _isLoading,
                onPressed: () => _sendEmail(),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14.w, color: AppColors.grey500),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.grey500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? AppColors.white : AppColors.grey700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
