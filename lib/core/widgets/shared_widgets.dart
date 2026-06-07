import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/profile_screen.dart';


String _anaArabicDigits(Object value) {
  var text = value.toString();
  const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  for (int i = 0; i < englishDigits.length; i++) {
    text = text.replaceAll(englishDigits[i], arabicDigits[i]);
  }

  return text;
}

String _localizedAnaNumber(BuildContext context, Object value) {
  return isArabic(context) ? _anaArabicDigits(value) : value.toString();
}

class AnaNotificationItem {
  final String id;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final IconData icon;
  final bool isOpened;

  AnaNotificationItem({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.createdAt,
    DateTime? scheduledAt,
    required this.icon,
    this.isOpened = false,
  }) : scheduledAt = scheduledAt ?? createdAt;

  factory AnaNotificationItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};
    final createdAtValue = data['createdAt'];
    final scheduledAtValue = data['scheduledAt'];

    DateTime createdAt = DateTime.now();
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    }

    DateTime scheduledAt = createdAt;
    if (scheduledAtValue is Timestamp) {
      scheduledAt = scheduledAtValue.toDate();
    }

    return AnaNotificationItem(
      id: doc.id,
      titleEn: data['titleEn'] ?? 'Notification',
      titleAr: data['titleAr'] ?? 'إشعار',
      bodyEn: data['bodyEn'] ?? '',
      bodyAr: data['bodyAr'] ?? '',
      createdAt: createdAt,
      scheduledAt: scheduledAt,
      icon: Icons.self_improvement_rounded,
      isOpened: data['isOpened'] ?? false,
    );
  }

  AnaNotificationItem copyWith({bool? isOpened}) {
    return AnaNotificationItem(
      id: id,
      titleEn: titleEn,
      titleAr: titleAr,
      bodyEn: bodyEn,
      bodyAr: bodyAr,
      createdAt: createdAt,
      scheduledAt: scheduledAt,
      icon: icon,
      isOpened: isOpened ?? this.isOpened,
    );
  }
}

class TopHelloBar extends StatefulWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback? onSettings;
  final List<AnaNotificationItem>? notifications;

  const TopHelloBar({
    super.key,
    required this.name,
    required this.onLogout,
    this.onSettings,
    this.notifications,
  });

  @override
  State<TopHelloBar> createState() => _TopHelloBarState();
}

class _TopHelloBarState extends State<TopHelloBar> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _dueNotificationRefreshTimer;

  @override
  void initState() {
    super.initState();

    // Firestore documents for scheduled in-app reminders are created before
    // their selected time. This timer makes the sheet/badge refresh when
    // scheduledAt becomes due while the app is open.
    _dueNotificationRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _dueNotificationRefreshTimer?.cancel();
    super.dispose();
  }

  String _initialsFromName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    }
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }

  String? _profilePhotoUrlFromData(Map<String, dynamic> data) {
    final rawUrl = data['profilePhotoUrl'] ??
        data['photoURL'] ??
        FirebaseAuth.instance.currentUser?.photoURL;
    final url = rawUrl?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  Stream<Map<String, dynamic>> _profileStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream<Map<String, dynamic>>.value(<String, dynamic>{});
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return <String, dynamic>{};
      return doc.data() ?? <String, dynamic>{};
    });
  }

  Widget _buildProfilePhotoImage({
    required String? profilePhotoUrl,
    required Widget Function() fallback,
  }) {
    final photoValue = profilePhotoUrl?.trim();

    if (photoValue == null || photoValue.isEmpty) {
      return fallback();
    }

    if (photoValue.startsWith('data:image/')) {
      try {
        final commaIndex = photoValue.indexOf(',');
        if (commaIndex <= 0 || commaIndex >= photoValue.length - 1) {
          return fallback();
        }

        final imageBytes = base64Decode(photoValue.substring(commaIndex + 1));
        return Image.memory(
          imageBytes,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback(),
        );
      } catch (e) {
        return fallback();
      }
    }

    return Image.network(
      photoValue,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  }

  Widget _buildTopAvatar(String? profilePhotoUrl) {
    Widget buildInitials() {
      return Center(
        child: Text(
          _initialsFromName(widget.name),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: _buildProfilePhotoImage(
          profilePhotoUrl: profilePhotoUrl,
          fallback: buildInitials,
        ),
      ),
    );
  }

  Stream<List<AnaNotificationItem>> _notificationsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream<List<AnaNotificationItem>>.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appNotifications')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();

      final notifications = snapshot.docs
          .map((doc) => AnaNotificationItem.fromFirestore(doc))
          .where((notification) => !notification.scheduledAt.isAfter(now))
          .toList();

      notifications.sort(
            (a, b) => b.scheduledAt.compareTo(a.scheduledAt),
      );

      return notifications;
    });
  }

  Future<void> _openNotifications(
      List<AnaNotificationItem> notifications,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsBottomSheet(
        onRetakeQuestionnaire: () {},
        notifications: notifications,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnaNotificationItem>>(
      stream: _notificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((notification) => !notification.isOpened).length;

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            child: Row(
              children: [
                StreamBuilder<Map<String, dynamic>>(
                  stream: _profileStream(),
                  builder: (context, profileSnapshot) {
                    final profilePhotoUrl = _profilePhotoUrlFromData(
                      profileSnapshot.data ?? <String, dynamic>{},
                    );

                    return _buildTopAvatar(profilePhotoUrl);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          context,
                          'Hello, ${widget.name}',
                          'مرحباً، ${widget.name}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          context,
                          'Welcome back to your inner space',
                          'أهلاً بعودتك إلى مساحتك الداخلية',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A6A5A),
                        ),
                      ),
                    ],
                  ),
                ),
                _TopBarIconButton(
                  icon: Icons.notifications_rounded,
                  onPressed: () => _openNotifications(notifications),
                  tooltip: tr(context, 'Notifications', 'الإشعارات'),
                  badgeCount: unreadCount,
                ),
                _TopBarIconButton(
                  icon: Icons.person_rounded,
                  tooltip: tr(context, 'Profile', 'الملف الشخصي'),
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: user,
                          onLogout: widget.onLogout,
                          initialUserCharacters: <UserCharacter>[],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final int badgeCount;

  const _TopBarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Container(
      margin: EdgeInsets.only(
        left: isArabicValue ? 0 : 8,
        right: isArabicValue ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            color: const Color(0xFF6A5CFF),
            tooltip: tooltip,
          ),
          if (badgeCount > 0)
            Positioned(
              top: -5,
              right: isArabicValue ? null : -5,
              left: isArabicValue ? -5 : null,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A7A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99
                        ? (isArabicValue ? '٩٩+' : '99+')
                        : _localizedAnaNumber(context, badgeCount),
                    textDirection:
                    isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatBubblesArc extends StatefulWidget {
  final void Function(String characterName) onTapCharacter;

  const ChatBubblesArc({super.key, required this.onTapCharacter});

  @override
  State<ChatBubblesArc> createState() => _ChatBubblesArcState();
}

class _ChatBubblesArcState extends State<ChatBubblesArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _leftSlide;
  late final Animation<Offset> _topSlide;
  late final Animation<Offset> _rightSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    _leftSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _topSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _rightSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Center(
          child: SizedBox(
            width: 280,
            height: 200,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 20,
                  left: 14,
                  child: SlideTransition(
                    position: _leftSlide,
                    child: _CharacterBubble(
                      label: tr(context, 'Character 1', 'الشخصية ١'),
                      icon: Icons.gavel_rounded,
                      onTap: () => widget.onTapCharacter('Inner Critic'),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: SlideTransition(
                    position: _topSlide,
                    child: _CharacterBubble(
                      label: tr(context, 'Character 2', 'الشخصية ٢'),
                      icon: Icons.emoji_emotions_rounded,
                      onTap: () => widget.onTapCharacter('Wounded Child'),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 14,
                  child: SlideTransition(
                    position: _rightSlide,
                    child: _CharacterBubble(
                      label: tr(context, 'Character 3', 'الشخصية ٣'),
                      icon: Icons.shield_rounded,
                      onTap: () => widget.onTapCharacter('Protector'),
                    ),
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

class _CharacterBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CharacterBubble({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
              border: Border.all(
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.28),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF2A1E3B), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsBottomSheet extends StatefulWidget {
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;
  final List<AnaNotificationItem>? notifications;
  final VoidCallback? onNotificationsOpened;

  const SettingsBottomSheet({
    super.key,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
    this.notifications,
    this.onNotificationsOpened,
  });

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late List<AnaNotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List<AnaNotificationItem>.from(
      widget.notifications ?? [],
    );
  }

  int get _unreadCount => _notifications.where((n) => !n.isOpened).length;

  Future<void> _markOneAsOpened(AnaNotificationItem notification) async {
    if (notification.isOpened) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _notifications = _notifications.map((item) {
        if (item.id == notification.id) {
          return item.copyWith(isOpened: true);
        }
        return item;
      }).toList();
    });

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('appNotifications')
          .doc(notification.id)
          .update({
        'isOpened': true,
        'openedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error opening notification: $e');
    }
  }

  String _timeAgo(BuildContext context, DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) {
      return tr(context, 'Just now', 'الآن');
    }
    if (difference.inMinutes < 60) {
      final minutes = _localizedAnaNumber(context, difference.inMinutes);
      return tr(
        context,
        '${difference.inMinutes} min ago',
        'منذ $minutes دقيقة',
      );
    }
    if (difference.inHours < 24) {
      final hours = _localizedAnaNumber(context, difference.inHours);
      return tr(
        context,
        '${difference.inHours} h ago',
        'منذ $hours ساعة',
      );
    }
    final days = _localizedAnaNumber(context, difference.inDays);
    return tr(
      context,
      '${difference.inDays} d ago',
      'منذ $days يوم',
    );
  }

  String _unreadSummary(BuildContext context) {
    if (_unreadCount == 0) {
      return tr(
        context,
        'All updates are opened',
        'تم فتح كل التحديثات',
      );
    }

    return tr(
      context,
      '$_unreadCount unopened update${_unreadCount == 1 ? '' : 's'}',
      '${_localizedAnaNumber(context, _unreadCount)} تحديث غير مفتوح',
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment:
            isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0C6E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                textDirection:
                isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: Color(0xFF8E7CFF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: isArabicValue
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'Notifications', 'الإشعارات'),
                          textAlign:
                          isArabicValue ? TextAlign.right : TextAlign.left,
                          textDirection: isArabicValue
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _unreadSummary(context),
                          textAlign:
                          isArabicValue ? TextAlign.right : TextAlign.left,
                          textDirection: isArabicValue
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A6A5A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF7A6A5A),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _notifications.isEmpty
                    ? _EmptyNotificationsState()
                    : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];

                    return GestureDetector(
                      onTap: () => _markOneAsOpened(notification),
                      child: _NotificationUpdateTile(
                        notification: notification,
                        timeAgo: _timeAgo(context, notification.scheduledAt),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationUpdateTile extends StatelessWidget {
  final AnaNotificationItem notification;
  final String timeAgo;

  const _NotificationUpdateTile({
    required this.notification,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isOpened ? const Color(0xFFF9F6FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.isOpened
                ? const Color(0xFFE5DEFF)
                : const Color(0xFF8E7CFF),
            width: notification.isOpened ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: notification.isOpened ? 0.03 : 0.07,
              ),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.icon,
                    color: const Color(0xFF8E7CFF),
                    size: 21,
                  ),
                ),
                if (!notification.isOpened)
                  Positioned(
                    top: -2,
                    right: isArabicValue ? null : -2,
                    left: isArabicValue ? -2 : null,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A7A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: isArabicValue
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    textDirection:
                    isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Expanded(
                        child: Text(
                          isArabicValue
                              ? notification.titleAr
                              : notification.titleEn,
                          textAlign:
                          isArabicValue ? TextAlign.right : TextAlign.left,
                          textDirection: isArabicValue
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        textAlign:
                        isArabicValue ? TextAlign.left : TextAlign.right,
                        textDirection: isArabicValue
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9C90B3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabicValue ? notification.bodyAr : notification.bodyEn,
                    textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                    textDirection:
                    isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: notification.isOpened
                          ? const Color(0xFFEFEAF8)
                          : const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      notification.isOpened
                          ? tr(context, 'Opened', 'تم الفتح')
                          : tr(context, 'New', 'جديد'),
                      textDirection:
                      isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: notification.isOpened
                            ? const Color(0xFF7A6A5A)
                            : const Color(0xFF6A5CFF),
                      ),
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

class _EmptyNotificationsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
          isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF8E7CFF),
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Text(
                tr(context, 'No notifications yet', 'لا توجد إشعارات بعد'),
                textAlign: isArabicValue ? TextAlign.right : TextAlign.center,
                textDirection:
                isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                tr(
                  context,
                  'Your daily task updates will appear here.',
                  'تحديثات المهام اليومية هتظهر هنا.',
                ),
                textAlign: isArabicValue ? TextAlign.right : TextAlign.center,
                textDirection:
                isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A6A5A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
