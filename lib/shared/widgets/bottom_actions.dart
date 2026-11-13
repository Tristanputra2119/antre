import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Thumb-reach action area pinned to the bottom of a page.
class BottomActions extends StatelessWidget {
  const BottomActions({
    super.key,
    required this.children,
    this.divided = false,
  });

  final List<Widget> children;

  /// Top hairline, used when content scrolls underneath.
  final bool divided;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.paper,
      border: divided
          ? Border(top: BorderSide(color: context.tokens.rule))
          : null,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kScreenPadding,
          divided ? 12 : 8,
          kScreenPadding,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// Small spinner sized for a 56dp button.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      color: context.tokens.onPrimary,
    ),
  );
}
