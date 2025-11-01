import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import các service và màn hình cần thiết
import '../services/user_service.dart';
import 'search_user_screen.dart'; // Màn hình tìm/thêm bạn bè mới
import 'chat_screen.dart';       // Màn hình chat
import 'user_info_screen.dart'; // <-- Đảm bảo bạn đã import

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

// Thêm SingleTickerProviderStateMixin để quản lý TabController
class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService(); // Khởi tạo UserService
  final User? currentUser = FirebaseAuth.instance.currentUser; // Lấy user hiện tại

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController với 2 tab
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Nút back tự động hiển thị
        iconTheme: const IconThemeData(color: Colors.white), // Màu nút back
        elevation: 0,
        // Nền gradient giống HomeScreen
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
           'Bạn bè',
           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Nút mở màn hình tìm kiếm để THÊM bạn mới
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white), // Icon thêm bạn
            tooltip: 'Thêm bạn bè',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUserScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        // TabBar nằm dưới AppBar
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          tabs: const [
            Tab(text: 'BẠN BÈ'),
            Tab(text: 'LỜI MỜI'),
          ],
        ),
      ),
      // Body sử dụng TabBarView để hiển thị nội dung theo Tab
      body: TabBarView(
        controller: _tabController,
        children: [
          // === Nội dung cho Tab "BẠN BÈ" ===
          _buildFriendListTab(),

          // === Nội dung cho Tab "LỜI MỜI" ===
          _buildFriendRequestsTab(),
        ],
      ),
    );
  }

  // --- Widget xây dựng nội dung cho Tab "BẠN BÈ" ---
  Widget _buildFriendListTab() {
    if (currentUser == null) return const Center(child: Text('Lỗi: Người dùng chưa đăng nhập.'));

    // Dùng StreamBuilder để lắng nghe danh sách bạn bè từ UserService
    return StreamBuilder<QuerySnapshot>(
      stream: _userService.getFriendsStream(), // Lấy stream bạn bè (status 'accepted')
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Lỗi tải danh sách bạn bè: ${snapshot.error}");
          return const Center(child: Text('Lỗi tải danh sách bạn bè.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
             child: Padding(
               padding: EdgeInsets.all(20.0),
               child: Text(
                  'Bạn chưa có bạn bè nào.\nNhấn nút (+) ở góc trên để tìm và thêm bạn mới!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
               ),
             ),
          );
        }

        final friendDocs = snapshot.data!.docs;

        return ListView.separated(
          itemCount: friendDocs.length,
          separatorBuilder: (context, index) => Divider(height: 1, indent: 80, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final doc = friendDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final List<dynamic> userIds = data['users'] ?? [];
            final Map<String, dynamic> userNames = data['userNames'] ?? {};
            final Map<String, dynamic> userAvatars = data['userAvatars'] ?? {};

            String friendUid = '';
            String friendName = 'Người bạn';
            String? friendAvatarUrl;
            for (var uid in userIds) {
              if (uid.toString() != currentUser!.uid) {
                friendUid = uid.toString();
                friendName = userNames[friendUid]?.toString() ?? 'Người bạn';
                friendAvatarUrl = userAvatars[friendUid]?.toString(); // Lấy avatar
                break;
              }
            }

            return ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               leading: CircleAvatar(
                  radius: 26,
                  backgroundImage: friendAvatarUrl != null && friendAvatarUrl.isNotEmpty
                      ? NetworkImage(friendAvatarUrl) 
                      : null,
                  backgroundColor: friendAvatarUrl == null || friendAvatarUrl.isEmpty
                      ? Colors.primaries[index % Colors.primaries.length].withAlpha(51)
                      : Colors.transparent,
                  child: (friendAvatarUrl == null || friendAvatarUrl.isEmpty)
                     ? Text(
                       friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.primaries[index % Colors.primaries.length]),
                     )
                     : null,
               ),
               title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
               subtitle: Text('Đang hoạt động', style: TextStyle(color: Colors.green.shade600, fontSize: 13)), // Placeholder
               trailing: IconButton(
                  icon: Icon(Icons.more_horiz, color: Colors.grey.shade500),
                  tooltip: 'Tùy chọn',
                  // === SỬA LỖI Ở ĐÂY ===
                  // Bỏ tham số 'friendAvatarUrl' cuối cùng
                  onPressed: () => _showFriendOptions(
                      context,
                      friendUid,
                      friendName,
                      doc.id, // friendshipDocId
                  ),
               ),
               onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                     ChatScreen(friendUid: friendUid, friendName: friendName)));
               },
            );
          },
        );
      },
    );
  }

  // --- Widget xây dựng nội dung cho Tab "LỜI MỜI" ---
  Widget _buildFriendRequestsTab() {
    if (currentUser == null) return const Center(child: Text('Lỗi người dùng'));

    return StreamBuilder<QuerySnapshot>(
      stream: _userService.getFriendRequestsStream(), // Lấy stream lời mời (status 'pending')
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           debugPrint("Lỗi tải lời mời: ${snapshot.error}");
          return const Center(child: Text('Không thể tải lời mời kết bạn.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Không có lời mời kết bạn nào.'));
        }

        final requestDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10.0),
          itemCount: requestDocs.length,
          itemBuilder: (context, index) {
            final doc = requestDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String requesterId = data['requesterId'] ?? '';
            final Map<String, dynamic> userNames = data['userNames'] ?? {};
            final Map<String, dynamic> userAvatars = data['userAvatars'] ?? {};
            String requesterName = userNames[requesterId]?.toString() ?? 'Người dùng';
            String? requesterAvatarUrl = userAvatars[requesterId]?.toString();
            final String friendshipDocId = doc.id; // ID của document friendship

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: ListTile(
                  leading: CircleAvatar(
                     radius: 26,
                     backgroundImage: requesterAvatarUrl != null && requesterAvatarUrl.isNotEmpty
                        ? NetworkImage(requesterAvatarUrl) 
                        : null,
                     backgroundColor: requesterAvatarUrl == null || requesterAvatarUrl.isEmpty 
                        ? Colors.blueGrey.shade50 
                        : Colors.transparent,
                     child: (requesterAvatarUrl == null || requesterAvatarUrl.isEmpty) 
                        ? const Icon(Icons.person_add_alt_1, color: Colors.blueAccent, size: 28) 
                        : null,
                  ),
                  title: Text(requesterName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Đã gửi lời mời kết bạn'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nút Từ chối
                      SizedBox(
                         height: 32,
                         width: 70,
                         child: OutlinedButton(
                           onPressed: () => _declineRequest(friendshipDocId),
                           child: const Text('Từ chối'),
                           style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 12),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                         ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Đồng ý
                      SizedBox(
                         height: 32,
                         width: 70,
                         child: ElevatedButton(
                           onPressed: () => _acceptRequest(friendshipDocId),
                           child: const Text('Đồng ý'),
                           style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                         ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

   // --- Helper Functions (Hàm xử lý logic) ---

   // Chấp nhận lời mời
   Future<void> _acceptRequest(String friendshipDocId) async {
     try {
       await _userService.acceptFriendRequest(friendshipDocId);
       if(mounted) _showSnack("Đã đồng ý kết bạn!");
     } catch (e) {
       if(mounted) _showError(e.toString());
     }
   }

   // Từ chối lời mời
   Future<void> _declineRequest(String friendshipDocId) async {
      try {
       // Từ chối nghĩa là xóa document friendship
       await _userService.removeFriendship(friendshipDocId);
       if(mounted) _showSnack("Đã từ chối lời mời.");
     } catch (e) {
       if(mounted) _showError(e.toString());
     }
   }

   // Hủy kết bạn
    Future<void> _unfriend(String friendshipDocId, String friendName) async {
       // Hiển thị dialog xác nhận
       bool? confirmUnfriend = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
             title: const Text('Xác nhận hủy kết bạn'),
             content: Text('Bạn có chắc muốn hủy kết bạn với $friendName không?'),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                TextButton(
                   onPressed: () => Navigator.pop(ctx, true),
                   child: const Text('Hủy kết bạn', style: TextStyle(color: Colors.red)),
                ),
             ],
          ),
       );

       if (confirmUnfriend == true) {
          try {
             // Hủy kết bạn cũng là xóa document friendship
             await _userService.removeFriendship(friendshipDocId);
             if (mounted) _showSnack("Đã hủy kết bạn với $friendName.");
          } catch (e) {
             if (mounted) _showError(e.toString());
          }
       }
   }

  // Hiển thị menu tùy chọn cho bạn bè (ĐÃ SỬA LỖI)
  void _showFriendOptions(BuildContext context, String friendUid, String friendName, String friendshipDocId) {
     showModalBottomSheet(
       context: context,
       shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
       ),
       builder: (ctx) {
         return Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.message_outlined, color: Colors.blueAccent),
                title: const Text('Nhắn tin'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(friendUid: friendUid, friendName: friendName),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.green),
                title: const Text('Xem trang cá nhân'),
                onTap: () {
                  Navigator.pop(ctx);
                  // === SỬA LỖI Ở ĐÂY ===
                  // Điều hướng đến UserInfoScreen bằng friendUid
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserInfoScreen(
                        friendUid: friendUid, // <-- Chỉ cần truyền UID
                      ),
                    ),
                  );
                  // ====================
                },
              ),
               ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Colors.red.shade700),
                title: Text('Hủy kết bạn', style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _unfriend(friendshipDocId, friendName); // Gọi hàm hủy kết bạn
                },
              ),
              const SizedBox(height: 10), // Khoảng đệm
            ],
         );
       },
     );
  }

  // --- Helper Functions cho SnackBar ---
   void _showSnack(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(message),
       backgroundColor: Colors.green.shade600,
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       duration: const Duration(seconds: 2),
     ));
   }
   void _showError(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(message),
       backgroundColor: Colors.red.shade700,
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       duration: const Duration(seconds: 3),
     ));
   }

} // End of _FriendsScreenState

