import 'package:flutter/material.dart';

import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/guider_chat_session_screen.dart';

/// Backward-compatible wrapper that now delegates to the session-based screen.
class GuiderChatScreen extends StatelessWidget {
  final ChatSessionModel session;
  final bool readOnly;

  const GuiderChatScreen({
    super.key,
    required this.session,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GuiderChatSessionScreen(
      session: session,
      readOnly: readOnly,
    );
  }
}
