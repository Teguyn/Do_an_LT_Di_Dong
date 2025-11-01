import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import để format thời gian
import '../services/user_service.dart'; // Import service
// Import màn hình chi tiết (cần tạo) và tạo nhóm
import 'group_detail_screen.dart'; // Đây sẽ là màn hình chat nhóm
import 'create_group_screen.dart';

class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UserService _userService = UserService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const Center(child: Text('Lỗi: Người dùng chưa đăng nhập.'));

    return Scaffold(
      // Dùng StreamBuilder để lấy danh sách nhóm
      body: StreamBuilder<QuerySnapshot>(
        stream: _userService.getGroupsStream(), // Gọi hàm lấy stream nhóm
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Lỗi tải danh sách nhóm: ${snapshot.error}");
            return const Center(child: Text('Lỗi tải danh sách nhóm.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Bạn chưa tham gia nhóm nào.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                       icon: const Icon(Icons.add_circle_outline),
                       label: const Text('Tạo nhóm mới'),
                       onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                          );
                       },
                    )
                  ],
                ),
              ),
            );
          }

          final groupDocs = snapshot.data!.docs;

          // TODO: Logic sắp xếp (ghim, chưa đọc) có thể thêm ở đây

          return ListView.separated(
            itemCount: groupDocs.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final doc = groupDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String groupName = data['groupName'] ?? 'Nhóm';
              final String? groupAvatarUrl = data['groupAvatarUrl'];
              final String lastMessage = data['lastMessage'] ?? '...';
              final Timestamp? lastMessageTime = data['lastMessageTime'] as Timestamp?;
              // TODO: Lấy trạng thái unread, pinned, muted từ data
              // final bool isUnread = data['unread_${currentUser.uid}'] ?? false; // Ví dụ
              // final bool isPinned = data['pinnedBy_${currentUser.uid}'] ?? false; // Ví dụ

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: groupAvatarUrl != null ? NetworkImage(groupAvatarUrl) : null,
                  backgroundColor: groupAvatarUrl == null ? Colors.primaries[index % Colors.primaries.length].withAlpha(51) : Colors.transparent,
                  child: (groupAvatarUrl == null)
                     ? Text(
                       groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.primaries[index % Colors.primaries.length]),
                     )
                     : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                         groupName,
                         // style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500),
                         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                    ),
                     // TODO: Thêm icon Pinned / Muted
                     // if (isPinned) Icon(...)
                     // if (isMuted) Icon(...)
                  ],
                ),
                subtitle: Text(
                  lastMessage,
                  // style: TextStyle(color: isUnread ? Colors.black87 : Colors.grey.shade600, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                   style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Text(
                        lastMessageTime != null ? _formatTimestamp(lastMessageTime.toDate()) : '',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                       // TODO: Thêm chỉ báo unread
                       // if (isUnread) Container(...)
                       // else
                       const SizedBox(height: 18),
                   ],
                ),
                onTap: () {
                  // TODO: Cập nhật logic đánh dấu đã đọc
                  // if (isUnread) { ... }

                  // Điều hướng đến màn hình chat nhóm
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailScreen(
                         // Truyền ID phòng chat
                         chatRoomId: doc.id,
                         groupName: groupName,
                         // avatarUrl: groupAvatarUrl,
                         // members: List<String>.from(data['users'] ?? []),
                      ),
                    ),
                  );
                },
                onLongPress: () {
                   // TODO: Hiển thị menu tùy chọn (ghim, ẩn, tắt thông báo...)
                   // _showOptions(context, index); // Cần điều chỉnh hàm _showOptions
                },
              );
            },
          );
        },
      ),
       // Nút FAB để tạo nhóm mới
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Mở màn hình CreateGroupScreen
          // Không cần chờ kết quả vì StreamBuilder sẽ tự cập nhật
           Navigator.push(
             context,
             MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
           );
        },
        // Style nút
         backgroundColor: const Color(0xFF6A11CB), // Màu gradient
         child: const Icon(Icons.add, color: Colors.white),
         tooltip: 'Tạo nhóm mới',
      ),
    );
  }

  // Hàm format thời gian (Copy từ ChatListScreen)
   String _formatTimestamp(DateTime time) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateToCheck = DateTime(time.year, time.month, time.day);

      try {
        if (dateToCheck == today) {
          return DateFormat.Hm().format(time); // 14:30
        } else if (dateToCheck == yesterday) {
          return 'Hôm qua';
        } else if (now.difference(time).inDays < 7) {
          try { return DateFormat.E('vi_VN').format(time); } // T2, T3
          catch (_) { return DateFormat.E().format(time); } // Mon, Tue
        } else {
          return DateFormat('dd/MM/yy').format(time); // 28/10/25
        }
      } catch (e) {
         debugPrint("Lỗi format thời gian: $e.");
         return "${time.day}/${time.month}";
      }
   }
}
