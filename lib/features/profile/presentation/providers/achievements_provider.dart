import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/providers.dart';
import '../../data/models/achievement_model.dart';
import '../../data/repositories/achievements_repository_impl.dart';

final profileAchievementsProvider =
    FutureProvider<List<AchievementModel>>((ref) async {
  return AchievementsRepositoryImpl(ref.watch(apiClientProvider))
      .getAchievements();
});
