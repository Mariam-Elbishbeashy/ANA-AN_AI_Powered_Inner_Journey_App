import 'package:flutter/material.dart';

const String guiderAvatarPath = 'assets/images/guider.png';

class GuiderAvatar extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final double? fallbackIconSize;

  const GuiderAvatar({
    super.key,
    required this.size,
    required this.backgroundColor,
    this.fallbackIcon = Icons.auto_awesome_rounded,
    this.fallbackIconColor = Colors.white,
    this.fallbackIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            guiderAvatarPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon,
              color: fallbackIconColor,
              size: fallbackIconSize ?? size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
