import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_header.dart';
import '../roadmap/roadmap_widgets.dart';

/// Plain page for short account tasks, such as resetting a password: the
/// app's usual back header, with the form on one white card.
class AccountFormPage extends StatelessWidget {
  const AccountFormPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  static InputDecoration inputDecoration(String hint) {
    const error = Color(0xFFB3261E);
    final colors = AppTheme.lightTheme.colorScheme;
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    const border = Color(0xFFE3ECF7);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
      filled: true,
      fillColor: AppTheme.pageBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      errorMaxLines: 4,
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(colors.primary, 1.5),
      errorBorder: outline(error),
      focusedErrorBorder: outline(error, 1.5),
    );
  }

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
    backgroundColor: AppTheme.primaryBlue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha: .55),
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontFamily: 'Google Sans',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.lightTheme,
    child: Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BackPageHeader(title, subtitle: subtitle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: RoadmapCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
