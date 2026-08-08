import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/cms_role.dart';
import '../providers/cms_admin_providers.dart';

/// Admin-only user role management. Assigns/revokes CMS roles via the
/// server-enforced `setUserRole` callable. Every change is recorded in the
/// audit log.
class CmsUsersScreen extends ConsumerStatefulWidget {
  final CmsRole callerRole;
  const CmsUsersScreen({super.key, required this.callerRole});

  @override
  ConsumerState<CmsUsersScreen> createState() => _CmsUsersScreenState();
}

class _CmsUsersScreenState extends ConsumerState<CmsUsersScreen> {
  final _uid = TextEditingController();
  CmsRole? _role; // null = revoke (none)
  bool _roleTouched = false;

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  Future<void> _submit(CmsRole caller) async {
    final uid = _uid.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (uid.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter the target user uid.')));
      return;
    }
    // Guard client-side (server re-checks): caller must be allowed to assign.
    if (!CmsRole.canAssign(caller, _role)) {
      messenger.showSnackBar(const SnackBar(
          content: Text('You are not allowed to assign that role.'),
          backgroundColor: AppColors.danger));
      return;
    }
    final err = await ref
        .read(setUserRoleControllerProvider.notifier)
        .assign(uid: uid, roleKey: _role?.key ?? 'none');
    if (!mounted) return;
    if (err == null) {
      messenger.showSnackBar(SnackBar(
          content: Text(_role == null
              ? 'Access revoked for $uid'
              : 'Granted ${_role!.label} to $uid')));
      _uid.clear();
      setState(() {
        _role = null;
        _roleTouched = false;
      });
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caller = widget.callerRole;
    final busy = ref.watch(setUserRoleControllerProvider).isLoading;

    if (!caller.canManageUsers) {
      return const Center(child: Text('You do not have access to user management.'));
    }

    // Roles this caller may assign (plus a Revoke option).
    final assignable =
        CmsRole.values.where((r) => CmsRole.canAssign(caller, r)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text('Admin users', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Grant or revoke CMS access by user uid. Changes take effect on '
              'the user\'s next token refresh and are recorded in the audit log.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: softCard(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _uid,
                    decoration: const InputDecoration(
                      labelText: 'User uid',
                      hintText: 'Firebase Auth uid of the target user',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CmsRole?>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [
                      const DropdownMenuItem<CmsRole?>(
                          value: null, child: Text('Revoke access (none)')),
                      for (final r in assignable)
                        DropdownMenuItem<CmsRole?>(
                            value: r, child: Text(r.label)),
                    ],
                    onChanged: (r) => setState(() {
                      _role = r;
                      _roleTouched = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: busy ? null : () => _submit(caller),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_user_rounded),
                    label: Text(_role == null && _roleTouched
                        ? 'Revoke access'
                        : 'Apply role'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: softCard(context),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      caller == CmsRole.superAdmin
                          ? 'As super admin you can assign any role, including admin.'
                          : 'As admin you can assign roles below admin; only a super admin can manage admins.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
