import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Lấy tham chiếu đến collection messages
  CollectionReference _messagesRef(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages');
  }

  // Lấy tham chiếu đến document phòng chat
  DocumentReference _chatRoomRef(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId);
  }

  // === 1. Thả cảm xúc ===
  Future<void> reactToMessage(String chatRoomId, String messageId, String reactionEmoji) async {
    if (currentUser == null) return;
    final String myUid = currentUser!.uid;
    
    try {
      // Dùng FieldValue.update để cập nhật một field trong map 'reactions'
      await _messagesRef(chatRoomId).doc(messageId).update({
        'reactions.$myUid': reactionEmoji
      });
    } catch (e) {
      debugPrint("Lỗi thả cảm xúc: $e");
      throw Exception("Không thể thả cảm xúc.");
    }
  }

  // === 2. Thu hồi tin nhắn ===
  Future<void> revokeMessage(String chatRoomId, String messageId) async {
     if (currentUser == null) return;
     try {
       await _messagesRef(chatRoomId).doc(messageId).update({
         'isRevoked': true,
         'text': 'Tin nhắn đã bị thu hồi'
         // (Bạn cũng có thể xóa 'text' và chỉ dựa vào 'isRevoked')
       });
     } catch (e) {
        debugPrint("Lỗi thu hồi tin nhắn: $e");
        throw Exception("Không thể thu hồi tin nhắn.");
     }
  }

  // === 3. Chỉnh sửa tin nhắn ===
  Future<void> editMessage(String chatRoomId, String messageId, String newText) async {
     if (currentUser == null) return;
     try {
       await _messagesRef(chatRoomId).doc(messageId).update({
         'text': newText,
         'editedAt': Timestamp.now(), // Đánh dấu là đã chỉnh sửa
       });
     } catch (e) {
        debugPrint("Lỗi sửa tin nhắn: $e");
        throw Exception("Không thể sửa tin nhắn.");
     }
  }

  // === 4. Ghim tin nhắn ===
  Future<void> pinMessage(String chatRoomId, DocumentSnapshot messageDoc) async {
     if (currentUser == null) return;
     try {
       // Lấy data từ messageDoc để ghim
       final messageData = messageDoc.data() as Map<String, dynamic>;
       
       // Tạo một bản sao 'lightweight' của tin nhắn để ghim
       final pinnedMessageData = {
         'messageId': messageDoc.id,
         'text': messageData['text'],
         'senderName': messageData['senderName'],
         'senderId': messageData['senderId'],
         'pinnedAt': Timestamp.now(),
         'pinnedBy': currentUser!.displayName ?? currentUser!.uid,
       };

       // Cập nhật document phòng chat
       await _chatRoomRef(chatRoomId).update({
         'pinnedMessage': pinnedMessageData,
       });

       // (Tùy chọn) Đánh dấu tin nhắn gốc là đã ghim
       await _messagesRef(chatRoomId).doc(messageDoc.id).update({
         'isPinned': true
       });

     } catch (e) {
       debugPrint("Lỗi ghim tin nhắn: $e");
       throw Exception("Không thể ghim tin nhắn.");
     }
  }

  // === 5. Bỏ ghim tin nhắn ===
  Future<void> unpinMessage(String chatRoomId, String messageId) async {
     try {
       // Xóa field 'pinnedMessage' khỏi phòng chat
       await _chatRoomRef(chatRoomId).update({
         'pinnedMessage': FieldValue.delete(),
       });
       // (Tùy chọn) Cập nhật tin nhắn gốc
       await _messagesRef(chatRoomId).doc(messageId).update({
         'isPinned': false
       });
     } catch (e) {
       debugPrint("Lỗi bỏ ghim: $e");
       throw Exception("Không thể bỏ ghim.");
     }
  }

  // === 6. Xóa tin nhắn (Chỉ xóa cho tôi) ===
  // Cách đơn giản nhất là xóa local, nhưng để đồng bộ
  // chúng ta sẽ thêm UID vào 1 mảng 'deletedFor'
  Future<void> deleteMessageForMe(String chatRoomId, String messageId) async {
     if (currentUser == null) return;
     try {
       await _messagesRef(chatRoomId).doc(messageId).update({
         'deletedFor': FieldValue.arrayUnion([currentUser!.uid])
       });
     } catch (e) {
       debugPrint("Lỗi xóa tin nhắn: $e");
       throw Exception("Không thể xóa tin nhắn.");
     }
  }

}