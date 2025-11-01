import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Cho debugPrint
// Đảm bảo đường dẫn đến các service và màn hình khác là đúng
import '../services/user_service.dart';
import 'chat_screen.dart'; // Màn hình chat
import 'user_info_screen.dart'; // Màn hình thông tin cá nhân

class SearchUserScreen extends StatefulWidget {
  // THÊM: ID của phòng chat cần thêm thành viên vào
  // Nếu là null, màn hình sẽ ở chế độ "Kết bạn"
  final String? chatRoomIdToAddTo; 
  // (Tùy chọn) Truyền danh sách thành viên hiện tại để lọc
  final List<String> currentGroupMembers; 

  const SearchUserScreen({
    super.key,
    this.chatRoomIdToAddTo, // Thêm vào constructor
    this.currentGroupMembers = const [], // Mặc định là list rỗng
  });

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  Stream<QuerySnapshot> _resultsStream = Stream.empty();
  List<String> _searchHistory = [];
  Timer? _debounce;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  static const String _historyKey = 'search_history';

  // Biến kiểm tra chế độ
  bool get _isAddingToGroup => widget.chatRoomIdToAddTo != null;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  // --- Quản lý Lịch sử Tìm kiếm ---
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _searchHistory = prefs.getStringList(_historyKey) ?? [];
      });
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentHistory = List<String>.from(_searchHistory);
    currentHistory.remove(query);
    currentHistory.insert(0, query);
    List<String> updatedHistory = currentHistory.length > 10
        ? currentHistory.sublist(0, 10)
        : currentHistory;
    await prefs.setStringList(_historyKey, updatedHistory);
    if (mounted) {
       setState(() { _searchHistory = updatedHistory; });
    }
  }

  Future<void> _clearSearchHistory() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove(_historyKey);
     if (mounted) {
       setState(() { _searchHistory = []; });
     }
  }

  // --- Xử lý Tìm kiếm ---
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.trim();
      if (mounted) {
        setState(() {
          if (query.isNotEmpty) {
             // Luôn tìm kiếm trong 'users' collection
             if (query.startsWith('+') || RegExp(r'^[0-9]{9,12}$').hasMatch(query)) {
                _resultsStream = _userService.searchUsersByPhone(query);
             } else {
                _resultsStream = _userService.searchUsersByName(query);
             }
          } else {
             _resultsStream = Stream.empty();
          }
        });
      }
    });
  }

  void _performSearchAndSaveHistory(String query) {
     if (query.isEmpty) return;
     _searchController.text = query;
     _searchController.selection = TextSelection.fromPosition(
         TextPosition(offset: query.length));
     // Chỉ lưu lịch sử nếu ở chế độ tìm bạn
     if (!_isAddingToGroup) {
        _saveSearchHistory(query);
     }
     FocusScope.of(context).unfocus();
  }


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Xây dựng Giao diện ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // AppBar với giao diện gradient đồng bộ
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            // Hint text thay đổi theo chế độ
            hintText: _isAddingToGroup ? 'Tìm bạn bè để thêm vào nhóm...' : 'Tìm theo tên hoặc số điện thoại...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => _performSearchAndSaveHistory(value.trim()),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8)),
              onPressed: () { _searchController.clear(); },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // Quyết định hiển thị nội dung gì
  Widget _buildBody() {
    // 1. Nếu đang gõ (có text) -> Luôn hiển thị kết quả tìm kiếm
    if (_searchController.text.isNotEmpty) {
      return _buildSearchResults();
    }
    // 2. Nếu không gõ VÀ đang ở chế độ "Thêm vào nhóm" -> Hiển thị danh sách bạn bè
    else if (_isAddingToGroup) {
      return _buildFriendListForAdding();
    }
    // 3. Nếu không gõ VÀ đang ở chế độ "Tìm bạn" -> Hiển thị lịch sử
    else {
      return _buildSearchHistory();
    }
  }

  // --- CÁC LOẠI BODY ---

  // Body 1: Hiển thị kết quả tìm kiếm (khi đang gõ)
  Widget _buildSearchResults() {
      return StreamBuilder<QuerySnapshot>(
        stream: _resultsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tìm kiếm: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không tìm thấy kết quả nào.'));
          }

          final results = snapshot.data!.docs;
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              // Lọc bỏ chính mình
              if (results[index].id == currentUser?.uid) {
                 return const SizedBox.shrink();
              }
              // Dùng FutureBuilder để lấy trạng thái bạn bè
              return FutureBuilder<DocumentSnapshot?>(
                  future: _userService.getFriendshipStatus(results[index].id),
                  builder: (context, statusSnapshot) {
                      return _buildUserResultTile(results[index], statusSnapshot);
                  },
              );
            },
          );
        },
      );
  }

  // Body 2: Hiển thị danh sách BẠN BÈ (khi ở chế độ Thêm vào nhóm và chưa gõ)
  Widget _buildFriendListForAdding() {
     if (currentUser == null) return const Center(child: Text('Lỗi người dùng'));

     return StreamBuilder<QuerySnapshot>(
       stream: _userService.getFriendsStream(), // Lấy danh sách bạn bè
       builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text('Bạn không có bạn bè nào để thêm.'));
          }
          final friendDocs = snapshot.data!.docs;

          return ListView.separated(
             itemCount: friendDocs.length,
             separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: Colors.grey.shade200),
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
                    friendAvatarUrl = userAvatars[friendUid]?.toString();
                    break;
                  }
                }

                // Kiểm tra xem bạn bè này đã ở trong nhóm chưa
                final bool isAlreadyInGroup = widget.currentGroupMembers.contains(friendUid);

                return ListTile(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                   leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: friendAvatarUrl != null ? NetworkImage(friendAvatarUrl) : null,
                      backgroundColor: friendAvatarUrl == null ? Colors.blueGrey.shade50 : Colors.transparent,
                      child: (friendAvatarUrl == null) ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                   ),
                   title: Text(friendName),
                   trailing: ElevatedButton(
                      child: Text(isAlreadyInGroup ? 'Đã thêm' : 'Thêm'),
                      onPressed: isAlreadyInGroup ? null : () => _addMemberToGroup(friendUid, friendName),
                      style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                         textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                         backgroundColor: isAlreadyInGroup ? Colors.grey.shade200 : Colors.blue.shade50,
                         foregroundColor: isAlreadyInGroup ? Colors.grey.shade600 : Colors.blue.shade800,
                         elevation: 0,
                      ),
                   ),
                );
             }
          );
       }
     );
  }

  // Body 3: Hiển thị Lịch sử Tìm kiếm (khi ở chế độ Tìm bạn và chưa gõ)
  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const Center(
        child: Padding(
           padding: EdgeInsets.all(30.0),
           child: Text(
             'Tìm kiếm bạn bè trong MyChat bằng tên hoặc số điện thoại đã đăng ký.',
             style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
             textAlign: TextAlign.center,
           ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 8.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text('Tìm kiếm gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
               TextButton(
                 onPressed: _clearSearchHistory,
                 child: const Text('Xóa tất cả', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                 style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
               ),
             ],
           ),
         ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query, style: const TextStyle(color: Colors.black87)),
                trailing: IconButton(
                   icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                   onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final List<String> currentHistory = List<String>.from(_searchHistory);
                      currentHistory.removeAt(index);
                       if (mounted) { setState(() { _searchHistory = currentHistory; }); }
                      await prefs.setStringList(_historyKey, currentHistory);
                   },
                   constraints: const BoxConstraints(),
                   padding: const EdgeInsets.all(8),
                   tooltip: 'Xóa khỏi lịch sử',
                ),
                onTap: () {
                  _performSearchAndSaveHistory(query);
                },
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget hiển thị một kết quả tìm kiếm (User)
  Widget _buildUserResultTile(DocumentSnapshot userDoc, AsyncSnapshot<DocumentSnapshot?> statusSnapshot) {
     Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
     String name = userData['name'] ?? 'Người dùng';
     String phone = userData['phone'] ?? '';
     String foundUserId = userDoc.id;
     String? avatarUrl = userData['avatarUrl'];

     // --- Xác định trạng thái bạn bè ---
     String status = 'not_friends';
     String friendshipDocId = '';
     String requesterId = '';

     if (statusSnapshot.connectionState == ConnectionState.done) {
          if (statusSnapshot.hasData && statusSnapshot.data != null && statusSnapshot.data!.exists) {
             final friendshipData = statusSnapshot.data!.data() as Map<String, dynamic>? ?? {};
             status = friendshipData['status'] ?? 'not_friends';
             friendshipDocId = statusSnapshot.data!.id;
             requesterId = friendshipData['requesterId'] ?? '';
          } else if (statusSnapshot.hasError) {
             debugPrint("Lỗi lấy friendship status trong UI: ${statusSnapshot.error}");
             status = 'error';
          } else {
              status = 'not_friends';
          }
     } else {
          status = 'loading';
     }

     // --- Widget Nút hành động ---
     Widget actionButton;
     // Kiểm tra xem có đang ở chế độ "Thêm vào nhóm" không
     if (_isAddingToGroup) {
        // Nếu là bạn bè, hiển thị nút "Thêm"
        if (status == 'accepted') {
           // Kiểm tra xem đã ở trong nhóm chưa
           bool isAlreadyInGroup = widget.currentGroupMembers.contains(foundUserId);
           actionButton = ElevatedButton(
             child: Text(isAlreadyInGroup ? 'Đã thêm' : 'Thêm'),
             onPressed: isAlreadyInGroup ? null : () => _addMemberToGroup(foundUserId, name),
             style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                backgroundColor: isAlreadyInGroup ? Colors.grey.shade200 : Colors.blue.shade50,
                foregroundColor: isAlreadyInGroup ? Colors.grey.shade600 : Colors.blue.shade800,
                elevation: 0,
             ),
           );
        } else {
           // Nếu chưa là bạn bè, không thể thêm vào nhóm
           actionButton = const SizedBox.shrink(); // Ẩn nút
        }
     } 
     // Nếu đang ở chế độ "Tìm bạn" (như cũ)
     else {
       switch (status) {
         case 'loading':
           actionButton = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
           break;
         case 'accepted':
           actionButton = IconButton(
             icon: Icon(Icons.message_outlined, color: Theme.of(context).primaryColor, size: 22),
             tooltip: 'Nhắn tin',
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(),
             onPressed: () => _navigateToChat(foundUserId, name),
           );
           break;
         case 'pending':
           if (requesterId == currentUser?.uid) { // Mình đã gửi
              actionButton = OutlinedButton(
                 onPressed: () => _cancelRequest(friendshipDocId),
                 child: const Text('Hủy YC'),
                 style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), textStyle: const TextStyle(fontSize: 12)),
              );
           } else { // Họ gửi cho mình
               actionButton = ElevatedButton(
                 onPressed: () => _acceptRequest(friendshipDocId),
                 child: const Text('Chấp nhận'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
               );
           }
           break;
         case 'error':
            actionButton = Tooltip(message: 'Lỗi', child: Icon(Icons.error_outline, color: Colors.red.shade300, size: 24));
            break;
         default: // 'not_friends', 'declined', 'removed'
           actionButton = ElevatedButton.icon(
             icon: const Icon(Icons.person_add_outlined, size: 16),
             label: const Text('Kết bạn'),
             onPressed: () => _sendRequest(foundUserId),
             style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor.withAlpha(26), foregroundColor: Theme.of(context).primaryColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
           );
       }
     }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: CircleAvatar(
         radius: 24,
         backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
         backgroundColor: avatarUrl == null ? Colors.blueGrey.shade50 : Colors.transparent,
         child: (avatarUrl == null) ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      subtitle: Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      trailing: actionButton,
      onTap: () {
          // Khi nhấn vào, luôn mở trang cá nhân
           Navigator.push(
             context,
             MaterialPageRoute(
               builder: (context) => UserInfoScreen(
                 friendUid: foundUserId,
               ),
             ),
           );
      },
    );
  }

  // --- Hàm Helper thực hiện các hành động ---
  void _navigateToChat(String friendUid, String friendName) {
     if (!_isAddingToGroup) _saveSearchHistory(_searchController.text.trim());
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
     setState(() { /* TODO: Bật loading */ });
     try {
        await _userService.sendFriendRequest(receiverId);
        if(mounted) _showSnack("Đã gửi lời mời kết bạn.");
     } catch (e) {
        if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { /* TODO: Tắt loading */ });
     }
  }

   Future<void> _acceptRequest(String friendshipDocId) async {
     debugPrint("Đang chấp nhận yêu cầu $friendshipDocId...");
     setState(() { /* TODO: Bật loading */ });
     try {
       await _userService.acceptFriendRequest(friendshipDocId);
       if(mounted) _showSnack("Kết bạn thành công!");
     } catch (e) {
       if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { /* TODO: Tắt loading */ });
     }
   }

   Future<void> _cancelRequest(String friendshipDocId) async {
      debugPrint("Đang hủy/từ chối yêu cầu $friendshipDocId...");
      setState(() { /* TODO: Bật loading */ });
     try {
       await _userService.removeFriendship(friendshipDocId);
       if(mounted) _showSnack("Đã hủy/từ chối lời mời.");
     } catch (e) {
       if(mounted) _showError(e.toString());
     } finally {
        if(mounted) setState(() { /* TODO: Tắt loading */ });
     }
   }
   
   // (MỚI) Hàm thêm thành viên vào nhóm
   Future<void> _addMemberToGroup(String newMemberUid, String newMemberName) async {
     if (widget.chatRoomIdToAddTo == null) return;
     debugPrint("Đang thêm $newMemberName ($newMemberUid) vào nhóm ${widget.chatRoomIdToAddTo}");
     
     setState(() { /* TODO: Bật loading */ });
     try {
        await _userService.addMemberToGroup(widget.chatRoomIdToAddTo!, newMemberUid);
        if (mounted) {
           _showSnack("Đã thêm $newMemberName vào nhóm.");
           // Cập nhật lại danh sách thành viên hiện tại (nếu cần)
           // (Tạm thời chỉ đóng màn hình)
           Navigator.pop(context);
        }
     } catch (e) {
        if (mounted) _showError(e.toString());
     } finally {
        setState(() { /* TODO: Tắt loading */ });
     }
  }


   // --- Hàm Helper hiển thị SnackBar ---
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

} // End of _SearchUserScreenState

