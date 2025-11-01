import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart'; // Import service

class SharedMediaScreen extends StatelessWidget {
  final String chatRoomId;
  final String participantName; // Tên nhóm hoặc tên bạn bè

  const SharedMediaScreen({
    super.key,
    required this.chatRoomId,
    required this.participantName,
  });

  @override
  Widget build(BuildContext context) {
    final UserService userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: Text("Ảnh & Video của $participantName"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
         iconTheme: const IconThemeData(color: Colors.white),
         titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userService.getSharedMediaStream(chatRoomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Lỗi tải media: ${snapshot.error}");
            return const Center(child: Text('Không thể tải media.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có ảnh hoặc video nào.'));
          }

          final mediaDocs = snapshot.data!.docs;

          // Hiển thị dạng lưới
          return GridView.builder(
            padding: const EdgeInsets.all(4.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 ảnh mỗi hàng
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: mediaDocs.length,
            itemBuilder: (context, index) {
              final doc = mediaDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String imageUrl = data['imageUrl'] ?? data['videoUrl'] ?? ''; // Lấy URL
              final bool isVideo = data['type'] == 'video';

              if (imageUrl.isEmpty) return Container(color: Colors.grey.shade200);

              return GestureDetector(
                onTap: () {
                  // TODO: Mở trình xem ảnh/video toàn màn hình
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      // Thêm loading
                      loadingBuilder: (context, child, loadingProgress) {
                         if (loadingProgress == null) return child;
                         return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      // Thêm xử lý lỗi
                       errorBuilder: (context, error, stackTrace) {
                         return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, color: Colors.grey));
                       },
                    ),
                    // Hiển thị icon Play nếu là video
                    if (isVideo)
                       const Center(
                         child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                       ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
