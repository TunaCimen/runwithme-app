import 'package:flutter/material.dart';
import '../../data/models/message_dto.dart';

/// Chat message bubble widget
class MessageBubble extends StatelessWidget {
  final MessageDto message;
  final bool isSent;
  final bool showTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSent ? 64 : 16,
        right: isSent ? 16 : 64,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSent ? const Color(0xFF7ED321) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isSent ? 16 : 4),
                bottomRight: Radius.circular(isSent ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isSent ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.timeString,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (isSent) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.isRead
                          ? const Color(0xFF7ED321)
                          : Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
