/// Maps Flutter endpoint paths to actual EV backend routes.
///
/// Now that api_endpoints.dart uses the correct backend paths directly,
/// this mapper only handles the remaining auth and a few legacy path translations.
class ContractMapper {
  const ContractMapper._();

  /// Translates the Flutter endpoint path to the actual backend route.
  static String mapPath({
    required String path,
    required bool evMode,
  }) {
    if (!evMode) return path;

    // ── Auth ──────────────────────────────────────────────────────────
    if (path == '/auth/otp/send') return '/auth/login';
    if (path == '/auth/otp/verify') return '/auth/verify_otp';
    // /auth/register stays the same
    // /auth/refresh stays the same

    // ── Profile Image ───────────────────────────────────────────────
    if (path == '/profile/image') return '/user/profile-image';

    // ── Groups ────────────────────────────────────────────────────────
    // Groups endpoints now use correct backend paths directly.

    // ── Subscription verify ─────────────────────────────────────────
    if (path == '/subscriptions/verify-id') return '/subscriptions/access/check';

    // ── Activity ────────────────────────────────────────────────────
    if (path == '/activity/summary') return '/trips/summary';
    if (path == '/activity/feed') return '/user/activity/';

    // ── Support ─────────────────────────────────────────────────────
    if (path == '/support/tickets') return '/issues/';
    if (path == '/support/chat') return '/faqs/';

    // All other paths (stations, wallet, trips, social, ride, user, etc.)
    // are now set to correct backend paths in api_endpoints.dart

    return path;
  }

  /// Returns true if the mapped path requires an admin auth header.
  static bool requiresAdminHeader(String path) {
    return path.startsWith('/admin/');
  }

  /// Returns true if the original path should use GET instead of POST.
  /// Backend uses GET for group join/leave despite being state-changing.
  static bool shouldUseGet(String originalPath) {
    if (RegExp(r'^/groups/[^/]+/join$').hasMatch(originalPath)) return true;
    if (RegExp(r'^/groups/[^/]+/leave$').hasMatch(originalPath)) return true;
    return false;
  }

  /// Transforms the request payload when the Flutter contract differs
  /// from the backend contract.
  static dynamic mapRequestData({
    required String originalPath,
    required dynamic data,
    required bool evMode,
  }) {
    if (!evMode || data == null) return data;

    // Registration: Flutter's AuthUserModel.toJson() uses 'id' but backend
    // expects 'uid' (auto-generated server-side) — strip client 'id'.
    if (originalPath == '/auth/register' && data is Map<String, dynamic>) {
      final mapped = Map<String, dynamic>.from(data);
      mapped.remove('id');
      mapped.remove('user_number');
      return mapped;
    }

    return data;
  }
}
