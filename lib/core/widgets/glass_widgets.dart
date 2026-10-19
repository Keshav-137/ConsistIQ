import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_background.dart';
import 'glass_container.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}

/// Full-screen page with the shared glass background.
class PageShell extends StatelessWidget {
  final Widget child;
  const PageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: GlassBackground(child: SafeArea(child: child)));
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: g.text)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!, style: TextStyle(fontSize: 14, color: g.subText)),
              ),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  const GlassIconButton({super.key, required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        radius: 16,
        blur: 12,
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 22, color: color ?? g.text),
      ),
    );
  }
}

/// Header for pushed screens: back button + title + optional trailing widget.
class SubHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SubHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: g.text)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: context.glass.subText)),
      );
}

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;
  final bool compact;
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
    this.filled = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final c = color ?? AppTheme.blue;
    final fg = filled ? Colors.white : g.text;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: filled ? LinearGradient(colors: [c, c.withValues(alpha: 0.72)]) : null,
              color: filled ? null : c.withValues(alpha: 0.14),
              border: Border.all(color: filled ? Colors.transparent : c.withValues(alpha: 0.45)),
            ),
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20, vertical: compact ? 10 : 14),
            child: Center(
              widthFactor: 1,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg, fontWeight: FontWeight.w700, fontSize: compact ? 13 : 15)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassContainer(
      radius: 18,
      blur: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        maxLines: obscure ? 1 : maxLines,
        minLines: 1,
        keyboardType: keyboardType,
        obscureText: obscure,
        onChanged: onChanged,
        cursorColor: AppTheme.blue,
        style: TextStyle(color: g.text, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: g.subText),
          hintStyle: TextStyle(color: g.subText.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final c = color ?? AppTheme.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? c.withValues(alpha: 0.28) : g.tintBottom,
          border: Border.all(color: selected ? c : g.border.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: selected ? g.text : g.subText), const SizedBox(width: 6)],
          Text(label,
              style: TextStyle(
                  color: selected ? g.text : g.subText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}

class StreakChip extends StatelessWidget {
  final int days;
  const StreakChip(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    if (days <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, size: 16, color: AppTheme.amber),
        const SizedBox(width: 3),
        Text('$days',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: context.glass.text)),
      ]),
    );
  }
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Row(children: [
      if (icon != null) Padding(padding: const EdgeInsets.only(right: 12), child: Icon(icon, color: g.subText)),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: g.text)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(fontSize: 12.5, color: g.subText)),
        ]),
      ),
      Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.blue),
    ]);
  }
}

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final String? label;
  final Color color;
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 80,
    this.label,
    this.color = AppTheme.blue,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(value: 1, strokeWidth: 8, color: g.text.withValues(alpha: 0.1)),
        ),
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        if (label != null)
          Text(label!, style: TextStyle(fontSize: size / 4.2, fontWeight: FontWeight.w800, color: g.text)),
      ]),
    );
  }
}

Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
      child: GlassContainer(
        radius: 28,
        blur: 30,
        padding: const EdgeInsets.all(20),
        child: SafeArea(top: false, child: SingleChildScrollView(child: Builder(builder: builder))),
      ),
    ),
  );
}

Future<bool> confirmGlass(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Confirm',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final g = ctx.glass;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: GlassContainer(
          radius: 28,
          blur: 30,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(fontSize: 14.5, color: g.subText)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: g.subText)),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: confirm,
                compact: true,
                filled: true,
                color: danger ? AppTheme.red : AppTheme.blue,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ]),
          ]),
        ),
      );
    },
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, String title, String initial) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final g = ctx.glass;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: GlassContainer(
          radius: 28,
          blur: 30,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 14),
            GlassField(controller: c, label: 'Text'),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: g.subText)),
              ),
              const SizedBox(width: 8),
              GlassButton(label: 'Save', compact: true, filled: true, onTap: () => Navigator.pop(ctx, c.text.trim())),
            ]),
          ]),
        ),
      );
    },
  );
  return (r == null || r.isEmpty) ? null : r;
}
