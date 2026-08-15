// Achievement definition + user progress.
//
// The admin panel controls every display attribute:
//   • title, description, category
//   • icon name, color hex
//   • threshold values (e.g. "ride 100 km")
//   • whether an achievement is active / visible
//
// The server merges the admin-defined template with the signed-in
// user's real progress before returning it from GET /profile/achievements.

class AchievementModel {
  final String id;

  /// Admin-controlled display text.
  final String title;
  final String description;

  /// Admin-defined grouping: 'riding' | 'social' | 'eco' | 'streak'
  final String category;

  /// Emoji or icon identifier string (e.g. "🏆" or "emoji_events").
  /// The UI maps this to a widget; admin sets it in the panel.
  final String icon;

  /// Hex colour string provided by admin, e.g. "#FFB300".
  final String colorHex;

  /// 0.0 – 1.0 progress toward unlocking; 1.0 means unlocked.
  final double progress;

  /// Whether the user has fully unlocked this achievement.
  final bool unlocked;

  /// ISO-8601 date string when the achievement was unlocked; null if locked.
  final String? unlockedDate;

  /// Human-readable threshold label set by admin, e.g. "Ride 100 km".
  final String? thresholdLabel;

  /// Whether the admin has marked this achievement as visible/active.
  final bool active;

  const AchievementModel({
    this.id = '',
    this.title = '',
    this.description = '',
    this.category = '',
    this.icon = '',
    this.colorHex = '#6C63FF',
    this.progress = 0.0,
    this.unlocked = false,
    this.unlockedDate,
    this.thresholdLabel,
    this.active = true,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id:             json['id']              as String? ?? '',
      title:          json['title']           as String? ?? '',
      description:    json['description']     as String? ?? '',
      category:       json['category']        as String? ?? '',
      icon:           json['icon']            as String? ?? '',
      colorHex:       json['color_hex']       as String? ?? '#6C63FF',
      progress:       (json['progress']       as num?)?.toDouble() ?? 0.0,
      unlocked:       json['unlocked']        as bool? ?? false,
      unlockedDate:   json['unlocked_date']   as String?,
      thresholdLabel: json['threshold_label'] as String?,
      active:         json['active']          as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':              id,
        'title':           title,
        'description':     description,
        'category':        category,
        'icon':            icon,
        'color_hex':       colorHex,
        'progress':        progress,
        'unlocked':        unlocked,
        'unlocked_date':   unlockedDate,
        'threshold_label': thresholdLabel,
        'active':          active,
      };
}
