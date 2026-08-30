import 'package:flutter/material.dart';

import 'placement_banner.dart';
import 'placement_campaign.dart';

/// A single drop-in slot that renders BOTH the live CMS banner and the top
/// sponsored campaign for a given [placement].
///
/// Both children render nothing when there is no live, targeted content for the
/// placement, so the slot stays completely invisible (zero height) until
/// marketing publishes something — no app release required. This is the
/// canonical way to expose a new banner/campaign location anywhere in the app:
/// add a [Placements] key and drop a [PlacementSlot] where it should appear.
class PlacementSlot extends StatelessWidget {
  final String placement;

  /// Outer padding applied only when at least one child is visible is not
  /// possible to know here cheaply, so keep this modest; the inner banner
  /// already adds its own bottom gap before the campaign.
  final EdgeInsetsGeometry padding;

  const PlacementSlot({
    super.key,
    required this.placement,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlacementBanner(
            placement: placement,
            padding: const EdgeInsets.only(bottom: 12),
          ),
          PlacementCampaign(placement: placement, padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}
