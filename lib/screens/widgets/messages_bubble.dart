import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Không cần trong tệp này

class MessageBubble extends StatelessWidget {
  // Nhận toàn bộ document snapshot
  final DocumentSnapshot messageDoc;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.messageDoc,
    required this.isMe,
  });

  // Hàm format thời gian (ví dụ: 10:30)
  String _formatTimestamp(Timestamp ts) {
    try {
      final DateTime dt = ts.toDate();
      return DateFormat.Hm().format(dt); // Hm() = 10:30 (24h)
    } catch (e) {
      return '...';
    }
  }
  
  // Hàm xây dựng widget hiển thị reactions
  Widget _buildReactions(Map<String, dynamic> reactions) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink(); // Không có reactions -> không hiển thị gì
    }
    
    // Đếm số lượng mỗi emoji
    final Map<String, int> reactionCounts = {};
    reactions.forEach((userId, emoji) {
       // Đảm bảo emoji là String
       if (emoji is String) {
         reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
       }
    });
    
    // Sắp xếp emoji theo số lượng
    final sortedReactions = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sắp xếp giảm dần

    return Positioned(
       bottom: -10, // Nổi bên dưới bong bóng chat
       right: isMe ? 10 : null,
       left: isMe ? null : 10,
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(10),
           boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))
           ]
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min, // Co lại vừa đủ
           children: sortedReactions.take(3).map((entry) { // Chỉ hiển thị 3 reactions phổ biến nhất
             return Padding(
               padding: const EdgeInsets.symmetric(horizontal: 2.0),
               child: Text(
                  // Hiển thị emoji và số lượng (nếu > 1)
                  '${entry.key} ${entry.value > 1 ? entry.value : ''}',
                  style: const TextStyle(fontSize: 12),
               ),
             );
           }).toList(),
         ),
       ),
    );
  }

  // === WIDGET MỚI ĐỂ HIỂN THỊ TIN NHẮN VĂN BẢN ===
  Widget _buildTextMessage(Map<String, dynamic> data, bool isRevoked, Color textColor) {
     final String message = data['text'] ?? '';
     final Timestamp timestamp = data['createdAt'] ?? Timestamp.now();
     final bool isEdited = data['editedAt'] != null;

     return Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.3,
                fontStyle: isRevoked ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdited && !isRevoked)
                Text(
                  '(đã chỉnh sửa) ',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.black54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
     );
  }

  // === WIDGET MỚI ĐỂ HIỂN THỊ TIN NHẮN ẢNH ===
  Widget _buildMediaMessage(BuildContext context, Map<String, dynamic> data, bool isRevoked, Color textColor) {
     final String? imageUrl = data['imageUrl'];
     final String? videoUrl = data['videoUrl'];
     final bool isVideo = (data['type'] ?? 'text') == 'video';

     // (Sửa) Nếu bị thu hồi, chỉ hiển thị bubble text
     if (isRevoked) {
        return _buildTextMessage(data, isRevoked, textColor);
     }

     String urlToShow = imageUrl ?? videoUrl ?? '';
     
     if (urlToShow.isEmpty) {
        return _buildTextMessage({'text': '[Lỗi tải media]', 'createdAt': data['createdAt']}, false, Colors.red.shade700);
     }

     return ConstrainedBox(
        constraints: BoxConstraints(
          // Đặt kích thước cố định hoặc tỷ lệ
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 250,
        ),
        child: Stack(
           alignment: Alignment.center,
           children: [
              // Hiển thị ảnh (dùng làm thumbnail cho cả ảnh và video)
              ClipRRect(
                 borderRadius: BorderRadius.circular(15), // Bo góc cho ảnh
                 child: Image.network(
                    urlToShow, // <-- Sửa: Dùng urlToShow
                    fit: BoxFit.cover,
                    // Hiển thị loading
                    loadingBuilder: (context, child, loadingProgress) {
                       if (loadingProgress == null) return child;
                       return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                    // Hiển thị lỗi
                    errorBuilder: (context, error, stackTrace) {
                       return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, color: Colors.grey, size: 40));
                    },
                 ),
              ),
              // Nếu là video, hiển thị icon Play
              if (isVideo)
                 Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                       color: Colors.black.withOpacity(0.5),
                       shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                 ),
           ],
        ),
     );
  }


  @override
  Widget build(BuildContext context) {
    final data = messageDoc.data() as Map<String, dynamic>? ?? {};
    
    // Lấy dữ liệu từ document
    final Timestamp timestamp = data['createdAt'] ?? Timestamp.now();
    final bool isRevoked = data['isRevoked'] ?? false;
    final Map<String, dynamic> reactions = data['reactions'] ?? {};
    final String type = data['type'] ?? 'text';
    
    // Sửa lỗi cú pháp 'rtl' (đảm bảo chữ thường)
    final bool isRTL = Directionality.of(context) == TextDirection.RTL;
    final bubbleAlignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    
    final bubbleColor = isMe
        ? (isRevoked ? Colors.grey.shade300 : Theme.of(context).primaryColor.withAlpha(220))
        : (isRevoked ? Colors.grey.shade200 : Colors.grey[200]);
        
    final textColor = isMe ? (isRevoked ? Colors.black54 : Colors.white) : (isRevoked ? Colors.black54 : Colors.black87);
    
    // Bo tròn 4 góc cho media, bo 3 góc cho text
    final borderRadius = (type == 'text' || isRevoked)
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          )
        : BorderRadius.circular(16); // Bo tròn 4 góc cho ảnh/video

    return Align(
       alignment: bubbleAlignment,
       child: Stack(
         clipBehavior: Clip.none, // Cho phép reactions nổi ra ngoài
         children: [
            // Bong bóng chat
            Container(
              // Bỏ padding nếu là media (và chưa bị thu hồi)
              padding: (type == 'text' || isRevoked) 
                  ? const EdgeInsets.symmetric(vertical: 10, horizontal: 16) 
                  : const EdgeInsets.all(3),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
              ),
              // Chọn widget để render dựa trên loại tin nhắn
              child: (type == 'image' || type == 'video')
                  ? _buildMediaMessage(context, data, isRevoked, textColor)
                  : _buildTextMessage(data, isRevoked, textColor),
            ),
            
            // Hiển thị reactions (nếu không bị thu hồi)
            if (!isRevoked)
               _buildReactions(reactions),
         ],
       ),
    );
  }
}

