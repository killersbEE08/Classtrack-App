import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/cms_marketing_repository.dart';
import '../../domain/cms_notification.dart';
import '../../domain/marketing.dart';

final cmsMarketingRepositoryProvider =
    Provider<CmsMarketingRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return CmsMarketingRepository(
    db: ref.watch(firestoreProvider),
    editorUid: uid,
  );
});

final cmsBannersProvider = StreamProvider<List<CmsBanner>>((ref) {
  final repo = ref.watch(cmsMarketingRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchBanners();
});

final cmsCampaignsProvider = StreamProvider<List<Campaign>>((ref) {
  final repo = ref.watch(cmsMarketingRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchCampaigns();
});

final cmsNotificationsProvider = StreamProvider<List<CmsNotification>>((ref) {
  final repo = ref.watch(cmsMarketingRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchNotifications();
});
