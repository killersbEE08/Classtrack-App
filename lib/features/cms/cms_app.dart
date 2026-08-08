import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'presentation/screens/cms_shell.dart';

/// The ClassTracks web CMS application. Reuses the mobile app's [AppTheme] so
/// the design language stays consistent, and its own auth/role gate
/// ([CmsShell]) — it deliberately does NOT depend on the mobile app's settings
/// providers (theme mode, shared prefs), so it runs standalone on the web.
class CmsApp extends ConsumerWidget {
  const CmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ClassTracks CMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const CmsShell(),
    );
  }
}
