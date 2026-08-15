import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/storage/local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.asset(
      'assets/animations/splash.mp4',
      viewType: defaultTargetPlatform == TargetPlatform.android
          ? VideoViewType.platformView
          : VideoViewType.textureView,
    );

    _controller
        .initialize()
        .then((_) async {
          if (!mounted) return;
          _controller
            ..setLooping(false)
            ..addListener(_onVideoProgress);
          setState(() {});
          await _controller.play();
        })
        .catchError((_) {
          _navigate();
        });

    // Fallback: navigate after 10 seconds in case video fails to load
    Future.delayed(const Duration(seconds: 10), _navigate);
  }

  void _onVideoProgress() {
    if (!_controller.value.isPlaying &&
        _controller.value.isInitialized &&
        _controller.value.position >= _controller.value.duration) {
      _navigate();
    }
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (LocalStorage.isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
