import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Modern 2026 Admin Design Kit
class AdminUiKit {
  static const Color primaryNavy = Color(0xFF0A1E3F);
  static const Color goldAccent = Color(0xFFDFB76C);
  static const Color goldHighlight = Color(0xFFF5E09D);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color roseRed = Color(0xFFEF4444);
  static const Color royalBlue = Color(0xFF3B82F6);
  static const Color amberOrange = Color(0xFFF59E0B);
  static const Color violetPurple = Color(0xFF8B5CF6);

  static void hapticLight() {
    HapticFeedback.lightImpact();
  }

  static void hapticMedium() {
    HapticFeedback.mediumImpact();
  }

  static void hapticSuccess() {
    HapticFeedback.selectionClick();
  }
}

/// Modern Glass Card with subtle border and adaptive surface
class AdminGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? customColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;
  final bool isGlowing;
  final Color? glowColor;

  const AdminGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.customColor,
    this.borderColor,
    this.borderRadius = 14,
    this.elevation = 0,
    this.isGlowing = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final bg = customColor ??
        (isDark
            ? const Color(0xFF13233D).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95));

    final border = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.primary.withValues(alpha: 0.08));

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isGlowing && glowColor != null
                ? glowColor!.withValues(alpha: 0.18)
                : (isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : theme.colorScheme.primary.withValues(alpha: 0.05)),
            blurRadius: isGlowing ? 20 : (elevation > 0 ? elevation * 4 : 12),
            offset: Offset(0, elevation > 0 ? elevation * 1.5 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap != null
                ? () {
                    AdminUiKit.hapticLight();
                    onTap!();
                  }
                : null,
            onLongPress: onLongPress != null
                ? () {
                    AdminUiKit.hapticMedium();
                    onLongPress!();
                  }
                : null,
            splashColor: AdminUiKit.goldAccent.withValues(alpha: 0.12),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );

    return content;
  }
}

/// Modern Section Header with glowing pill indicator
class AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? badgeText;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.badgeText,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 14, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AdminUiKit.goldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 14,
                color: AdminUiKit.goldAccent,
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AdminUiKit.goldAccent, AdminUiKit.goldHighlight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              ),
            ),
          ),
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AdminUiKit.goldAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AdminUiKit.goldAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                badgeText!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy,
                ),
              ),
            ),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Modern Animated Search Bar with glass fill and instant clear
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const AdminSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onClear,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF13233D).withValues(alpha: 0.7)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (hasText)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  splashRadius: 18,
                  color: isDark ? Colors.white60 : Colors.black45,
                  onPressed: () {
                    AdminUiKit.hapticLight();
                    controller.clear();
                    onClear?.call();
                    onChanged?.call('');
                    FocusScope.of(context).unfocus();
                  },
                ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 4),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Modern Status & Role Badge
class AdminStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isOutlined;
  final double fontSize;

  const AdminStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isOutlined = false,
    this.fontSize = 11,
  });

  factory AdminStatusBadge.active([String label = 'Active']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.emeraldGreen,
        icon: Icons.check_circle_rounded,
      );

  factory AdminStatusBadge.pending([String label = 'Pending']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.amberOrange,
        icon: Icons.access_time_rounded,
      );

  factory AdminStatusBadge.review([String label = 'Review']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.royalBlue,
        icon: Icons.rate_review_rounded,
      );

  factory AdminStatusBadge.danger([String label = 'Blocked']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.roseRed,
        icon: Icons.block_rounded,
      );

  factory AdminStatusBadge.admin([String label = 'ADMIN']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.goldAccent,
        icon: Icons.shield_rounded,
      );

  factory AdminStatusBadge.moderator([String label = 'MODERATOR']) => AdminStatusBadge(
        label: label,
        color: AdminUiKit.violetPurple,
        icon: Icons.verified_user_rounded,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isOutlined ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isOutlined ? 0.6 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern Primary Gradient Button
class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final bool isSecondary;
  final double height;
  final double borderRadius;

  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.isSecondary = false,
    this.height = 44,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryBg = color ??
        (isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy);
    final textColor = color != null
        ? Colors.white
        : (isDark ? AdminUiKit.primaryNavy : Colors.white);

    if (isSecondary) {
      return SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: isLoading
              ? null
              : () {
                  AdminUiKit.hapticLight();
                  onPressed?.call();
                },
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isDark ? Colors.white24 : theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryBg,
            Color.lerp(primaryBg, Colors.black, 0.15) ?? primaryBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: primaryBg.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: (isLoading || onPressed == null)
              ? null
              : () {
                  AdminUiKit.hapticMedium();
                  onPressed!();
                },
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: textColor, size: 17),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Modern Empty State with animated illustration
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminUiKit.goldAccent.withValues(alpha: 0.1),
                border: Border.all(
                  color: AdminUiKit.goldAccent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AdminUiKit.goldAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AdminUiKit.primaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AdminPrimaryButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onPressed: onAction,
                height: 44,
                borderRadius: 12,
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }
}
