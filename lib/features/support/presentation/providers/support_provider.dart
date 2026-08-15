import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/support_repository.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../../../core/network/providers.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepositoryImpl(ref.watch(apiClientProvider));
});
