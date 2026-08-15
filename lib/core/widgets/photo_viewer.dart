import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';

/// Shows a full-screen profile photo viewer.
/// Falls back to a large initials circle if no image is available.
void showPhotoViewer(
  BuildContext context, {
  String? imagePath,
  String? imageUrl,
  required String name,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => _PhotoViewerPage(
      imagePath: imagePath,
      imageUrl: imageUrl,
      name: name,
    ),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _PhotoViewerPage extends StatelessWidget {
  final String? imagePath;
  final String? imageUrl;
  final String name;

  const _PhotoViewerPage({
    this.imagePath,
    this.imageUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    Widget avatar;
    if (imagePath != null) {
      avatar = ClipOval(
        child: Image.file(
          File(imagePath!),
          width: 240.w,
          height: 240.w,
          fit: BoxFit.cover,
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          imageUrl!,
          width: 240.w,
          height: 240.w,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _InitialsCircle(initials: initials, size: 240),
        ),
      );
    } else {
      avatar = _InitialsCircle(initials: initials, size: 240);
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 20.w, color: Colors.white),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 240.w,
                        height: 240.w,
                        child: avatar,
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
}

class _InitialsCircle extends StatelessWidget {
  final String initials;
  final double size;

  const _InitialsCircle({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: (size * 0.38).sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
