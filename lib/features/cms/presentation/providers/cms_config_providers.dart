import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../opportunities/domain/recommendation_weights.dart';

/// Admin-only writer for `config/recommendation`. Firestore rules restrict
/// writes to admins; the read provider lives with the opportunities feature
/// (recommendationWeightsProvider) and is reused here.
class CmsConfigRepository {
  final FirebaseFirestore _db;
  CmsConfigRepository(this._db);

  Future<void> saveRecommendationWeights(RecommendationWeights w) {
    return _db
        .collection(AppConstants.configCollection)
        .doc(AppConstants.recommendationConfigDoc)
        .set({
      ...w.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final cmsConfigRepositoryProvider = Provider<CmsConfigRepository>((ref) {
  return CmsConfigRepository(ref.watch(firestoreProvider));
});
