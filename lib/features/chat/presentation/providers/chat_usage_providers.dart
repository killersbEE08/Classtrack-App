import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../subscription/domain/pro_constants.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../data/chat_usage_repository.dart';

/// Monthly AI chat usage tracker for the current user (null when signed out).
final chatUsageRepositoryProvider = Provider<ChatUsageRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ChatUsageRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Live count of AI messages used this month.
final chatMonthlyCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(chatUsageRepositoryProvider);
  if (repo == null) return Stream.value(0);
  return repo.watchCount();
});

/// Remaining free AI messages this month. Returns null for Pro (unlimited).
final chatRemainingProvider = Provider<int?>((ref) {
  if (ref.watch(isProProvider)) return null; // unlimited
  final used = ref.watch(chatMonthlyCountProvider).valueOrNull ?? 0;
  final left = ProConstants.freeMonthlyChatLimit - used;
  return left < 0 ? 0 : left;
});
