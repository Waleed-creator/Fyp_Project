import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../design_system/app_design_system.dart';

/// Modern App Bar Component with consistent styling
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;
  final Color? backgroundColor;
  final bool centerTitle;

  const ModernAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.showLogo = false,
    this.backgroundColor,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.lightCyan,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      title: showLogo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Crop the bottom portion to remove "SafeNest" text
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1, // Show top 80% (complete shield visible, text hidden)
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 35,
                      width: 35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingS),
                Text(
                  'Guardly',
                  style: AppDesignSystem.headline3.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ],
            )
          : title != null
              ? Text(
                  title!,
                  style: AppDesignSystem.headline3.copyWith(
                    color: AppColors.textDark,
                  ),
                )
              : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

