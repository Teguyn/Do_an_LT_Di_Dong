import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Cho debugPrint
import '../services/user_service.dart';
import '../services/chat_service.dart';
import 'user_info_screen.dart'; // Để xem trang cá nhân
import 'create_group_screen.dart'; // Để tạo nhóm chung
// (MỚI) Import 2 màn hình mới
import 'shared_media_screen.dart';
import 'common_groups_screen.dart';

class ChatOptionsScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;
  final String chatRoomId; // Đây chính là friendshipDocId cho chat 1-1

  const ChatOptionsScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.chatRoomId,
  });

  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  // Biến state cục bộ để cập nhật nhanh UI, 
  // StreamBuilder sẽ cập nhật giá trị thật từ DB
  bool? _isMuted;
  bool? _isBlocked;

  // --- Helper Functions cho SnackBar ---
  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }
  void _showError(String message) { _showSnack(message.replaceFirst("Exception: ", ""), isError: true); }
  // ===================================

  // Hàm xử lý tạo nhóm chung
  void _createCommonGroup() {
    // Tạo một Friend object giả lập từ thông tin hiện tại
    final preselectedFriend = Friend(
      uid: widget.friendUid,
      name: widget.friendName,
      phone: '', // SĐT không bắt buộc ở đây
      // avatarUrl: ... (có thể lấy từ friendData nếu bạn tải nó)
      isSelected: true, // Chọn sẵn
    );

    // Mở CreateGroupScreen và truyền bạn bè đã được chọn sẵn
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(
          // Truyền danh sách bạn bè đã chọn trước
          preSelectedFriends: [preselectedFriend], 
        ),
      ),
    );
  }
  
  // Hàm xóa lịch sử (Giữ nguyên)
  Future<void> _deleteHistory() async {
     bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text('Xác nhận xóa'),
           content: Text('Bạn có chắc muốn xóa toàn bộ lịch sử trò chuyện với ${widget.friendName}?'),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              TextButton(
                 onPressed: () => Navigator.pop(ctx, true),
                 child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
           ],
        ),
     );
     
     if (confirmDelete != true) return;
     
     try {
       // 1. Xóa sub-collection 'messages'
       final messagesRef = FirebaseFirestore.instance
           .collection('chat_rooms')
           .doc(widget.chatRoomId)
           .collection('messages');
           
       final messagesSnapshot = await messagesRef.get();
       WriteBatch batch = FirebaseFirestore.instance.batch();
       for (var doc in messagesSnapshot.docs) {
         batch.delete(doc.reference);
       }
       await batch.commit();
       
       // 2. Cập nhật tin nhắn cuối (để ChatList biết)
       await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.chatRoomId).update({
         'lastMessage': 'Đã xóa lịch sử trò chuyện.',
         'lastMessageTime': Timestamp.now(),
         // (Tùy chọn) Xóa tin nhắn ghim nếu có
         'pinnedMessage': FieldValue.delete(),
       });
       
       if (mounted) _showSnack("Đã xóa lịch sử trò chuyện.");
       
     } catch (e) {
       if (mounted) _showError("Lỗi khi xóa: ${e.toString()}");
     }
  }


  @override
  Widget build(BuildContext context) {
    // DÙNG STREAMBUILDER ĐỂ LẤY THÔNG TIN FRIENDSHIP (MUTE/BLOCK)
    // Tệp UserService (bên trái) phải có hàm `getFriendshipStream`
    return StreamBuilder<DocumentSnapshot>(
      // chatRoomId của 1-1 chat chính là friendshipDocId
      stream: _userService.getFriendshipStream(widget.chatRoomId), 
      builder: (context, snapshot) {
         
         // Lấy trạng thái mute/block hiện tại từ snapshot
         bool isMuted = _isMuted ?? false; // Dùng state cục bộ nếu có
         bool isBlocked = _isBlocked ?? false; // Dùng state cục bộ nếu có

         if (snapshot.connectionState == ConnectionState.active && snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            // Cập nhật state thật từ DB
            isMuted = data['mutedBy_${currentUser?.uid}'] ?? false;
            isBlocked = data['blockedBy_${currentUser?.uid}'] ?? false;
         }

         return Scaffold(
           backgroundColor: Colors.grey.shade100,
           appBar: AppBar(
             title: const Text("Tùy chọn"),
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
           body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. Phần Header (Avatar và Tên)
                _buildHeader(snapshot.data), // Truyền snapshot vào
                
                // 2. Phần Các nút hành động chính
                _buildActionButtons(),
                
                const SizedBox(height: 10),

                // 3. Danh sách các tùy chọn
                _buildFunctionList(isMuted, isBlocked), // Truyền state vào
              ],
            ),
          ),
         );
      },
    );
  }

  // --- Widget con ---

  Widget _buildHeader(DocumentSnapshot? friendshipDoc) {
    String? avatarUrl;

    // Lấy avatarUrl từ document friendship (nếu có)
    if (friendshipDoc != null && friendshipDoc.exists) {
       final data = friendshipDoc.data() as Map<String, dynamic>;
       final avatars = data['userAvatars'] as Map<String, dynamic>? ?? {};
       avatarUrl = avatars[widget.friendUid]?.toString();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
            backgroundColor: Colors.grey.shade300,
            child: (avatarUrl == null || avatarUrl.isEmpty) 
                ? const Icon(Icons.person, size: 50, color: Colors.white) 
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            widget.friendName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
       color: Colors.white,
       padding: const EdgeInsets.symmetric(vertical: 10.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: [
           _buildActionButton(
              context, 
              Icons.person_search, 
              'Trang cá nhân', 
              () {
                 Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserInfoScreen(friendUid: widget.friendUid),
                    ),
                 );
              }
           ),
           _buildActionButton(
              context, 
              Icons.call, 
              'Gọi thoại', 
              () { _showSnack("Chức năng Gọi thoại chưa có"); }
           ),
           _buildActionButton(
              context, 
              Icons.videocam, 
              'Gọi video', 
              () { _showSnack("Chức năng Gọi video chưa có"); }
           ),
         ],
       ),
    );
  }

  Widget _buildFunctionList(bool isMuted, bool isBlocked) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.search, color: Colors.black54),
            title: const Text('Tìm tin nhắn'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               _showSnack("Chức năng Tìm tin nhắn (chưa thực hiện)");
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.black54),
            title: const Text('Ảnh, video đã gửi'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (_) => SharedMediaScreen(
                    chatRoomId: widget.chatRoomId,
                    participantName: widget.friendName,
                 ))
               );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off_outlined, color: Colors.black54),
            title: const Text('Tắt thông báo'),
            value: isMuted, // Lấy giá trị từ StreamBuilder
            onChanged: (bool value) {
              // Cập nhật UI ngay lập tức
              setState(() => _isMuted = value); 
              // Gọi UserService để cập nhật
              _userService.updateFriendshipData(widget.chatRoomId, {
                'mutedBy_${currentUser?.uid}': value 
              }).then((_) {
                 _showSnack(value ? "Đã tắt thông báo" : "Đã bật thông báo");
              }).catchError((e) {
                 _showError(e.toString());
                 // Rollback UI nếu lỗi
                 if (mounted) setState(() => _isMuted = !value);
              });
            },
          ),
          const Divider(height: 1, indent: 56), // Thụt lề theo icon
          
          ListTile(
            leading: const Icon(Icons.group_add_outlined, color: Colors.black54),
            title: Text('Tạo nhóm chung với ${widget.friendName}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _createCommonGroup,
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined, color: Colors.black54),
            title: const Text('Xem nhóm chung'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (_) => CommonGroupsScreen(
                    friendUid: widget.friendUid,
                    friendName: widget.friendName,
                 ))
               );
            },
          ),
          const Divider(height: 1, indent: 56),

          SwitchListTile(
            secondary: Icon(Icons.block, color: Colors.red.shade700),
            title: Text('Chặn người dùng', style: TextStyle(color: Colors.red.shade700)),
            value: isBlocked, // Lấy giá trị từ StreamBuilder
            activeColor: Colors.red.shade700,
            onChanged: (bool value) {
              setState(() => _isBlocked = value);
              // Gọi UserService
              _userService.updateFriendshipData(widget.chatRoomId, {
                'blockedBy_${currentUser?.uid}': value
              }).then((_) {
                 _showSnack(value ? "Đã chặn người dùng này" : "Đã bỏ chặn");
              }).catchError((e) {
                 _showError(e.toString());
                 if (mounted) setState(() => _isBlocked = !value);
              });
            },
          ),
           ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
            title: Text('Xóa lịch sử trò chuyện', style: TextStyle(color: Colors.red.shade700)),
            onTap: _deleteHistory,
          ),
        ],
      ),
    );
  }

  // Widget helper cho các nút hành động (Trang cá nhân, Gọi, ...)
  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withAlpha(26), // Nền xanh nhạt
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

