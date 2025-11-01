import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Cho debugPrint
import '../services/user_service.dart'; // Import service

// Model Friend
class Friend {
  final String uid;
  final String name;
  final String phone;
  final String? avatarUrl;
  bool isSelected;

  Friend({
    required this.uid,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.isSelected = false,
  });
}

class CreateGroupScreen extends StatefulWidget {
  // (MỚI) Nhận danh sách bạn bè được chọn trước
  final List<Friend>? preSelectedFriends;

  const CreateGroupScreen({
    super.key,
    this.preSelectedFriends,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  File? _groupAvatar;

  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<Friend> _allFriends = []; // Danh sách tất cả bạn bè
  List<Friend> _filteredFriends = []; // Danh sách đã lọc
  bool _isLoading = true; // Đang tải bạn bè
  bool _isCreating = false; // Đang tạo nhóm

  @override
  void initState() {
    super.initState();
    _loadFriends();
    searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // Tải danh sách bạn bè từ Firestore
  Future<void> _loadFriends() async {
    if (currentUser == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Lấy danh sách UID bạn bè từ document 'friendships'
      final friendsSnapshot = await _userService.getFriendsStream().first; // Lấy dữ liệu 1 lần
      List<String> friendUids = [];

      for (var doc in friendsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> userIds = data['users'] ?? [];
        for (var uid in userIds) {
          if (uid.toString() != currentUser!.uid) {
            friendUids.add(uid.toString());
            break;
          }
        }
      }

      if (friendUids.isEmpty) {
         if(mounted) setState(() => _isLoading = false);
         return; // Không có bạn
      }
      
      // 2. Lấy thông tin chi tiết của từng người bạn
      // (Lưu ý: whereIn giới hạn 10 UIDs, cần chia nhỏ nếu > 10)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendUids)
          .get();

      List<Friend> loadedFriends = [];
      for (var userDoc in usersSnapshot.docs) {
         final data = userDoc.data() as Map<String, dynamic>? ?? {};
         
         // Kiểm tra xem có được chọn trước không
         bool isPreSelected = widget.preSelectedFriends
              ?.any((f) => f.uid == userDoc.id) ?? false;

         loadedFriends.add(Friend(
           uid: userDoc.id,
           name: data['name'] ?? 'Người dùng',
           phone: data['phone'] ?? '',
           avatarUrl: data['avatarUrl'],
           isSelected: isPreSelected, // <-- Gán giá trị chọn trước
         ));
      }

      if (mounted) {
         setState(() {
           _allFriends = loadedFriends;
           _filteredFriends = loadedFriends;
           _isLoading = false;
         });
      }

    } catch (e) {
       debugPrint("Lỗi tải danh sách bạn bè: $e");
       if (mounted) {
          setState(() => _isLoading = false);
          _showError("Không thể tải danh sách bạn bè.");
       }
    }
  }

  // Lọc danh sách bạn bè
  void _filterFriends() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      _filteredFriends = _allFriends
          .where((f) =>
              f.name.toLowerCase().contains(query) ||
              f.phone.contains(query))
          .toList();
    });
  }

  // Chọn ảnh cho nhóm
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _groupAvatar = File(picked.path);
      });
    }
  }

  List<Friend> get selectedFriends =>
      _allFriends.where((f) => f.isSelected).toList();

  // Hàm tạo nhóm (gọi service)
  Future<void> _createGroup() async {
     final name = nameController.text.trim();
     final selected = selectedFriends;

     if (name.isEmpty) {
       _showError("Vui lòng nhập tên nhóm");
       return;
     }
     // Sửa: Phải chọn ít nhất 2 người (ngoài bạn) để tạo nhóm
     if (selected.isEmpty) {
       _showError("Vui lòng chọn ít nhất 1 thành viên (ngoài bạn)");
       return;
     }

     setState(() => _isCreating = true);

     try {
        // Lấy danh sách UID của thành viên đã chọn
        final memberUids = selected.map((f) => f.uid).toList();
        
        // Gọi UserService để tạo nhóm
        // (Lưu ý: admin (bạn) sẽ tự động được thêm vào bên trong service)
        await _userService.createGroupChat(
           groupName: name,
           groupAvatarFile: _groupAvatar,
           memberUids: memberUids, 
        );

        if (mounted) {
           _showSnack("Tạo nhóm thành công!");
           // Pop 2 lần nếu được mở từ ChatOptions (ChatOptions -> CreateGroup -> Pop 2 lần về ChatScreen)
           // Pop 1 lần nếu được mở từ GroupChatScreen
           int popCount = 0;
           Navigator.of(context).popUntil((route) {
              // Nếu bạn mở từ ChatOptions (qua 2 push) thì popCount == 2
              // Nếu bạn mở từ GroupChatScreen (qua 1 push) thì route.isFirst (là HomeScreen) sẽ dừng
              // Cập nhật: An toàn nhất là pop 1 lần
              // Navigator.of(context).pop();
              // Hoặc Pop về tận root (HomeScreen)
               return route.isFirst;
           });
        }

     } catch (e) {
        debugPrint("Lỗi tạo nhóm (UI): $e");
         if (mounted) _showError("Lỗi tạo nhóm: ${e.toString()}");
     } finally {
        if (mounted) setState(() => _isCreating = false);
     }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Tạo nhóm mới"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
         iconTheme: const IconThemeData(color: Colors.white), // Đổi màu nút back
         titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), // Style title
      ),
      body: Stack( // Dùng Stack để hiển thị loading overlay
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chọn Avatar
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.blueAccent.shade100,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                _groupAvatar != null ? FileImage(_groupAvatar!) : null,
                            child: _groupAvatar == null
                                ? const Icon(Icons.group_add, size: 50, color: Colors.blueAccent)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18, // Tăng kích thước
                            backgroundColor: Colors.blueAccent,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Nhập tên nhóm
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Tên nhóm",
                    prefixIcon: const Icon(Icons.group, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Tăng khoảng cách
                
                // Hiển thị số lượng đã chọn
                Text(
                  "Đã chọn ${selectedFriends.length} thành viên",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),

                // Thanh tìm kiếm bạn bè
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Tìm kiếm bạn bè...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10), // Giảm chiều cao
                  ),
                  // onChanged đã được xử lý bởi listener
                ),
                const SizedBox(height: 16),

                // Danh sách bạn bè
                _isLoading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ))
                  : _allFriends.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Text('Bạn chưa có bạn bè nào để thêm.', style: TextStyle(color: Colors.grey)),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            return CheckboxListTile(
                              value: friend.isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  friend.isSelected = value ?? false;
                                });
                              },
                              secondary: CircleAvatar(
                                backgroundImage: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty 
                                  ? NetworkImage(friend.avatarUrl!) 
                                  : null,
                                child: (friend.avatarUrl == null || friend.avatarUrl!.isEmpty) 
                                  ? Text(friend.name.isNotEmpty ? friend.name[0] : '?') 
                                  : null,
                              ),
                              title: Text(friend.name),
                              subtitle: Text(friend.phone),
                            );
                          },
                        ),
                const SizedBox(height: 30),

                // Nút Tạo Nhóm
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0, // Bỏ shadow (vì đã có Ink)
                    backgroundColor: Colors.transparent, // Nền trong suốt
                    shadowColor: Colors.transparent,
                  ),
                  // Vô hiệu hóa nút khi đang tạo
                  onPressed: _isCreating ? null : _createGroup, 
                  child: Ink( // Dùng Ink để tạo nền gradient cho nút
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      height: 50, // Chiều cao cố định
                      alignment: Alignment.center,
                      // Hiển thị loading hoặc text
                      child: _isCreating
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text(
                              "TẠO NHÓM",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lớp phủ loading khi đang tạo
          if (_isCreating)
             Container(
                color: Colors.black.withAlpha(77), // ~30% opacity
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
             ),
        ],
      ),
    );
  }

  // --- Helper Functions cho SnackBar ---
   void _showSnack(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(message),
       backgroundColor: Colors.green.shade600,
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.all(10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
     ));
   }
   void _showError(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(message.replaceFirst("Exception: ", "")), // Cắt bỏ "Exception: "
       backgroundColor: Colors.red.shade700,
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.all(10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
     ));
   }
}

