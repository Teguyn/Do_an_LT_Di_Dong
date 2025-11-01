import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Cho debugPrint
import '../widgets/messages_bubble.dart'; 

// === WIDGET HIỂN THỊ TIN NHẮN (MessagesWidget) ===
class MessagesWidget extends StatelessWidget {
  final String chatRoomId;
  final String currentUserId;
  final String friendName;
  final VoidCallback onSendGreeting;
  final Function(DocumentSnapshot) onMessageLongPress;
  final bool isGroupChat; // ✅ MỚI: xác định đây là phòng nhóm hay 1-1

  const MessagesWidget({
    super.key,
    required this.chatRoomId,
    required this.currentUserId,
    required this.friendName,
    required this.onSendGreeting,
    required this.onMessageLongPress,
    this.isGroupChat = false, // mặc định là chat 1-1
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
          return _buildEmptyChatPlaceholder(context, friendName, onSendGreeting);
        }

        if (chatSnapshot.hasError) {
          debugPrint("Lỗi tải tin nhắn: ${chatSnapshot.error}");
          return const Center(child: Text('Không thể tải tin nhắn.'));
        }

        final loadedMessages = chatSnapshot.data!.docs;

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          itemCount: loadedMessages.length,
          itemBuilder: (ctx, index) {
            final messageDoc = loadedMessages[index];
            final messageData = messageDoc.data() as Map<String, dynamic>;
            final bool isMe = messageData['senderId'] == currentUserId;

            final List<dynamic> deletedFor = messageData['deletedFor'] ?? [];
            if (deletedFor.contains(currentUserId)) {
              return const SizedBox.shrink();
            }

            // ✅ Thêm phần hiển thị tên người gửi cho nhóm
            final senderName = messageData['senderName'] ?? 'Người lạ';

            return GestureDetector(
              onLongPress: () => onMessageLongPress(messageDoc),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // ✅ Chỉ hiển thị tên người gửi nếu là nhóm và không phải tin nhắn của mình
                  if (isGroupChat && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, bottom: 2.0),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  // Bubble tin nhắn
                  MessageBubble(
                    messageDoc: messageDoc,
                    isMe: isMe,
                    key: ValueKey(messageDoc.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Placeholder khi chưa có tin nhắn
  Widget _buildEmptyChatPlaceholder(
      BuildContext context, String friendName, VoidCallback onSendGreeting) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 15),
            Text(
              friendName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Các bạn đã được kết nối.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onSendGreeting,
              icon: const Icon(Icons.waving_hand_outlined, size: 18),
              label: const Text('Gửi lời chào'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1,
              ),
            )
          ],
        ),
      ),
    );
  }
}
