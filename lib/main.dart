import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  await LocalStorage.ensureAppUserId(); // guarantee every user has an ID
  runApp(const ProviderScope(child: NewtraApp()));
}

class NewtraApp extends ConsumerWidget {
  const NewtraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return ScreenUtilInit(
      // Design reference: iPhone 14 / 375×812 logical pixels
      designSize: const Size(375, 812),
      // Use the smaller axis scale for text so fonts don't balloon on tablets
      minTextAdapt: true,
      // Required for correct sizing in split-screen / tablet multi-window modes
      splitScreenMode: true,
      // Cap font scaling so text stays readable but never overflows on large screens
      fontSizeResolver: (fontSize, instance) {
        final scale = instance.scaleWidth.clamp(0.85, 1.35);
        return fontSize * scale;
      },
      builder: (context, child) {
        return MaterialApp.router(
          title: 'newtra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
          // Clamp OS-level accessibility text scaling so layouts never break
          builder: (context, routerChild) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.25,
                ),
              ),
              child: routerChild ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

