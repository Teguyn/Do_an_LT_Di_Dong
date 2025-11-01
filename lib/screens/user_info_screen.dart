import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart'; // Import UserService
import 'chat_screen.dart'; // Import ChatScreen

class UserInfoScreen extends StatefulWidget {
  final String friendUid;
  // Bỏ friendName, status, avatarUrl vì chúng ta sẽ tải chúng từ friendUid
  
  const UserInfoScreen({
    super.key,
    required this.friendUid,
  });

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  Map<String, dynamic>? _friendData; // Lưu thông tin người bạn
  String _friendshipStatus = 'loading'; // Trạng thái: loading, not_friends, pending_sent, pending_received, accepted
  String _friendshipDocId = ''; // ID của document friendship (nếu có)

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Tải đồng thời thông tin user và trạng thái bạn bè
  Future<void> _loadAllData() async {
    if (currentUser == null) return;
    
    setState(() { _isLoading = true; });

    try {
      // 1. Lấy thông tin người bạn
      final friendDoc = await _userService.getUserData(widget.friendUid);
      if (friendDoc != null && friendDoc.exists) {
        _friendData = friendDoc.data() as Map<String, dynamic>;
      } else {
        throw Exception("Không tìm thấy người dùng.");
      }

      // 2. Lấy trạng thái bạn bè
      final statusDoc = await _userService.getFriendshipStatus(widget.friendUid);
      if (statusDoc != null && statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        _friendshipDocId = statusDoc.id;
        _friendshipStatus = data['status'] ?? 'not_friends';
        
        // Kiểm tra xem ai là người gửi yêu cầu (nếu đang pending)
        if (_friendshipStatus == 'pending') {
          final requesterId = data['requesterId'];
          if (requesterId == currentUser!.uid) {
            _friendshipStatus = 'pending_sent'; // Mình đã gửi
          } else {
            _friendshipStatus = 'pending_received'; // Mình nhận được
          }
        }
      } else {
        _friendshipStatus = 'not_friends'; // Chưa có mối quan hệ
      }

    } catch (e) {
      debugPrint("Lỗi tải dữ liệu trang cá nhân: $e");
      if (mounted) _showError(e.toString());
       _friendshipStatus = 'error';
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dùng CustomScrollView để AppBar có thể "trôi" (nếu muốn)
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friendData == null
              ? const Center(child: Text('Không tìm thấy người dùng.'))
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(), // AppBar với ảnh bìa và avatar
                    SliverList(
                      delegate: SliverChildListDelegate([
                        _buildActionButtons(), // Nút Nhắn tin, Kết bạn
                        _buildInfoSection(),   // Thông tin (SĐT, v.v.)
                        _buildPostFeed(),      // Phần Bài viết
                      ]),
                    ),
                  ],
                ),
    );
  }

  // --- Widget con ---

  // 1. AppBar (Ảnh bìa, Avatar, Tên)
  Widget _buildSliverAppBar() {
    final String name = _friendData?['name'] ?? 'Người dùng';
    final String? avatarUrl = _friendData?['avatarUrl'];
    // TODO: Lấy ảnh bìa (coverUrl) từ _friendData nếu có
    // final String? coverUrl = _friendData?['coverUrl'];

    return SliverAppBar(
      expandedHeight: 200.0, // Chiều cao của ảnh bìa
      floating: false,
      pinned: true, // Giữ AppBar thu nhỏ ở trên cùng
      iconTheme: const IconThemeData(color: Colors.white), // Nút back màu trắng
      backgroundColor: const Color(0xFF2575FC), // Màu nền khi cuộn lên
      flexibleSpace: FlexibleSpaceBar(
        // Tiêu đề thu nhỏ (khi cuộn)
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 72, bottom: 16),
        // Nền (Ảnh bìa và Avatar)
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Ảnh bìa (Placeholder)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              // TODO: Thay thế bằng ảnh bìa thật
              // child: coverUrl != null
              //     ? Image.network(coverUrl, fit: BoxFit.cover)
              //     : Container(color: Colors.blueGrey),
            ),
            // Lớp phủ mờ
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0.0, 0.5),
                  end: Alignment(0.0, 0.0),
                  colors: <Color>[
                    Color(0x60000000), // Lớp mờ ở dưới
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
            // Avatar (Chồng lên ảnh bìa)
            Positioned(
              bottom: -1, // Nằm sát viền dưới (để có viền trắng)
              left: 16,
              child: Container(
                 padding: const EdgeInsets.all(4), // Viền trắng
                 decoration: BoxDecoration(
                   color: Colors.white,
                   shape: BoxShape.circle,
                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: Offset(0, 2))]
                 ),
                 child: CircleAvatar(
                   radius: 40,
                   backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                   backgroundColor: Colors.grey.shade200,
                   child: avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                 ),
              )
            ),
          ],
        ),
      ),
    );
  }

  // 2. Các nút hành động (Nhắn tin, Kết bạn)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          // Nút Nhắn tin (Luôn hiển thị)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.message_rounded),
              label: const Text('Nhắn tin'),
              onPressed: () => _navigateToChat(widget.friendUid, _friendData?['name'] ?? 'Người dùng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2575FC), // Màu xanh
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nút Bạn bè (Thay đổi theo trạng thái)
          Expanded(
            child: _buildFriendshipButton(),
          ),
        ],
      ),
    );
  }

  // 3. Widget cho nút Bạn bè (logic phức tạp)
  Widget _buildFriendshipButton() {
     // TODO: Cập nhật state của nút khi nhấn mà không cần đợi _loadAllData()
     // Hiện tại, nó sẽ tự cập nhật sau khi _loadAllData (chạy khi init)
     
     switch (_friendshipStatus) {
       case 'accepted': // Đã là bạn
         return OutlinedButton.icon(
           icon: const Icon(Icons.check, size: 18),
           label: const Text('Bạn bè'),
           onPressed: () { /* TODO: Mở menu (Hủy kết bạn) */
              _showUnfriendMenu();
           },
           style: OutlinedButton.styleFrom(
             foregroundColor: Colors.black87,
             side: BorderSide(color: Colors.grey.shade400),
             padding: const EdgeInsets.symmetric(vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           ),
         );
       case 'pending_sent': // Mình đã gửi YC
         return OutlinedButton.icon(
           icon: const Icon(Icons.undo, size: 18),
           label: const Text('Hủy YC'),
           onPressed: () => _cancelRequest(_friendshipDocId),
            style: OutlinedButton.styleFrom(
             foregroundColor: Colors.redAccent,
             side: BorderSide(color: Colors.red.shade200),
             padding: const EdgeInsets.symmetric(vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           ),
         );
       case 'pending_received': // Họ gửi YC cho mình
         return ElevatedButton.icon(
           // === SỬA LỖI Ở ĐÂY ===
           // Icon "person_add_done" không tồn tại.
           // icon: const Icon(Icons.person_add_done, size: 18), 
           icon: const Icon(Icons.check, size: 18), // Thay bằng Icons.check (✓)
           // ====================
           label: const Text('Chấp nhận'),
           onPressed: () => _acceptRequest(_friendshipDocId),
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.green.shade600,
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           ),
           // TODO: Thêm nút "Từ chối"
         );
       default: // 'not_friends', 'declined', 'removed', 'error'
         return ElevatedButton.icon(
           icon: const Icon(Icons.person_add, size: 18),
           label: const Text('Kết bạn'),
           onPressed: () => _sendRequest(widget.friendUid),
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.blue.shade50,
             foregroundColor: Colors.blue.shade800,
             elevation: 0,
             padding: const EdgeInsets.symmetric(vertical: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           ),
         );
     }
  }

  // 4. Thông tin cơ bản (Số điện thoại)
  Widget _buildInfoSection() {
     final String phone = _friendData?['phone'] ?? 'Chưa cập nhật';
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_outlined, color: Colors.grey.shade600),
              title: Text(phone, style: const TextStyle(fontSize: 16)),
              subtitle: const Text('Số điện thoại'),
            ),
             ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cake_outlined, color: Colors.grey.shade600),
              title: const Text('28 tháng 10, 1999', style: TextStyle(fontSize: 16)), // Placeholder
              subtitle: const Text('Ngày sinh'),
            ),
             const Divider(),
         ],
       ),
     );
  }

  // 5. Phần Bài viết (Placeholder)
  Widget _buildPostFeed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
             'Bài viết',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Placeholder cho một bài viết
          _buildPostCard(
            postContent: 'Hôm nay trời đẹp quá! Cùng đi cafe nào. ☕️ #flutterdev',
            timestamp: '2 giờ trước',
            likeCount: 15,
            commentCount: 3,
          ),
          _buildPostCard(
            postContent: 'Vừa hoàn thành dự án MyChat bằng Flutter. Cảm thấy thật tuyệt vời!',
            timestamp: '1 ngày trước',
            likeCount: 42,
            commentCount: 8,
          ),
        ],
      ),
    );
  }

  // Widget placeholder cho một bài viết
  Widget _buildPostCard({required String postContent, required String timestamp, required int likeCount, required int commentCount}) {
     final String name = _friendData?['name'] ?? 'Người dùng';
     final String? avatarUrl = _friendData?['avatarUrl'];

     return Card(
       margin: const EdgeInsets.only(bottom: 15),
       elevation: 2,
       shadowColor: Colors.grey.shade50,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       child: Padding(
         padding: const EdgeInsets.all(12.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Header của post (Avatar, Tên, Thời gian)
             Row(
               children: [
                 CircleAvatar(
                   radius: 20,
                   backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                   backgroundColor: Colors.grey.shade200,
                   child: avatarUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                 ),
                 const SizedBox(width: 10),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                     Text(timestamp, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                   ],
                 ),
               ],
             ),
             const SizedBox(height: 12),
             // Nội dung post
             Text(postContent, style: const TextStyle(fontSize: 15, height: 1.4)),
             const SizedBox(height: 12),
             // Lượt like, comment
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('$likeCount lượt thích', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                   Text('$commentCount bình luận', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
             ),
             const Divider(height: 20),
             // Nút Like, Comment
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildPostActionButton(icon: Icons.thumb_up_alt_outlined, label: 'Thích'),
                   _buildPostActionButton(icon: Icons.comment_outlined, label: 'Bình luận'),
                   _buildPostActionButton(icon: Icons.share_outlined, label: 'Chia sẻ'),
                ],
             )
           ],
         ),
       ),
     );
  }

  // Nút nhỏ cho Post Card
  Widget _buildPostActionButton({required IconData icon, required String label}) {
     return InkWell(
       onTap: () {},
       borderRadius: BorderRadius.circular(5),
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
         child: Row(
           children: [
             Icon(icon, size: 20, color: Colors.grey.shade600),
             const SizedBox(width: 8),
             Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
           ],
         ),
       ),
     );
  }


  // --- Helper Functions (Xử lý logic nút bấm) ---
  void _navigateToChat(String friendUid, String friendName) {
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => ChatScreen(
           friendUid: friendUid,
           friendName: friendName,
         ),
       ),
     );
  }

  Future<void> _sendRequest(String receiverId) async {
     debugPrint("Đang gửi yêu cầu tới $receiverId...");
     setState(() { _isLoading = true; }); // Bật loading tạm thời
     try {
        await _userService.sendFriendRequest(receiverId);
        if(mounted) _showSnack("Đã gửi lời mời kết bạn.");
        await _loadAllData(); // Tải lại trạng thái để cập nhật nút
     } catch (e) {
        if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { _isLoading = false; });
     }
  }

   Future<void> _acceptRequest(String friendshipDocId) async {
     debugPrint("Đang chấp nhận yêu cầu $friendshipDocId...");
     setState(() { _isLoading = true; });
     try {
       await _userService.acceptFriendRequest(friendshipDocId);
       if(mounted) _showSnack("Kết bạn thành công!");
       await _loadAllData(); // Tải lại trạng thái
     } catch (e) {
       if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { _isLoading = false; });
     }
   }

   Future<void> _cancelRequest(String friendshipDocId) async {
      debugPrint("Đang hủy yêu cầu $friendshipDocId...");
      setState(() { _isLoading = true; });
     try {
       await _userService.removeFriendship(friendshipDocId);
      if(mounted) _showSnack("Đã hủy lời mời kết bạn.");
       await _loadAllData(); // Tải lại trạng thái
     } catch (e) {
       if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { _isLoading = false; });
     }
   }

   Future<void> _unfriend(String friendshipDocId, String friendName) async {
      bool? confirm = await showDialog<bool>(
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

      if (confirm == true) {
        setState(() { _isLoading = true; });
         try {
           await _userService.removeFriendship(friendshipDocId);
           if (mounted) _showSnack("Đã hủy kết bạn với $friendName.");
           await _loadAllData(); // Tải lại trạng thái
         } catch (e) {
           if (mounted) _showError(e.toString());
         } finally {
            if(mounted) setState(() { _isLoading = false; });
         }
      }
   }

   // Menu cho nút "Bạn bè"
   void _showUnfriendMenu() {
      showModalBottomSheet(
         context: context,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
         ),
         builder: (ctx) {
           return Wrap(
              children: [
                 ListTile(
                   leading: Icon(Icons.person_remove_outlined, color: Colors.red.shade700),
                   title: Text('Hủy kết bạn', style: TextStyle(color: Colors.red.shade700)),
                   onTap: () {
                     Navigator.pop(ctx); // Đóng bottom sheet
                     _unfriend(_friendshipDocId, _friendData?['name'] ?? 'Người bạn');
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.block, color: Colors.grey),
                   title: const Text('Chặn người dùng'),
                   onTap: () {
                      Navigator.pop(ctx);
                       // TODO: Thêm logic chặn
                       _showError("Chức năng chặn chưa được thực hiện");
                   },
                 ),
                 const SizedBox(height: 10),
              ],
           );
         }
      );
   }

   // --- SnackBar Helper ---
   void _showSnack(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(message),
       backgroundColor: Colors.green.shade600,
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.all(10),
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
       margin: const EdgeInsets.all(10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       duration: const Duration(seconds: 3),
     ));
   }

}

