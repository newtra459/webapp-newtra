import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Global API client provider — the singleton anchor for all network requests.
/// Import this file from any feature that needs an [ApiClient], rather than
/// importing a feature-specific provider file.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
