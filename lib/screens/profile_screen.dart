import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
// Import các service
import '../services/auth_service.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Controllers để giữ dữ liệu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // State variables
  bool _isLoading = true; // Đang tải dữ liệu ban đầu
  bool _isSaving = false; // Đang lưu thay đổi
  bool _isEditing = false; // Đang ở chế độ chỉnh sửa

  String? _avatarUrl;
  String? _coverUrl;
  String _phoneNumber = ""; // Để lưu SĐT

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Bắt đầu tải dữ liệu khi màn hình được tạo
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Hàm tải dữ liệu người dùng từ Firestore
  Future<void> _loadUserData() async {
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Không thể tải thông tin, người dùng chưa đăng nhập.");
      return;
    }
    
    if (mounted) setState(() => _isLoading = true);

    try {
      final userDoc = await _userService.getUserData(currentUser!.uid);
      if (userDoc != null && userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameController.text = data['name'] ?? 'Chưa có tên';
          _bioController.text = data['bio'] ?? 'Hãy thêm tiểu sử của bạn...';
          _avatarUrl = data['avatarUrl'];
          _coverUrl = data['coverUrl'];
          _phoneNumber = data['phone'] ?? '';
          _isLoading = false;
        });
      } else {
         if (mounted) {
            setState(() => _isLoading = false);
            _showError("Không tìm thấy dữ liệu người dùng.");
         }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Lỗi tải dữ liệu: ${e.toString()}");
      }
    }
  }

  // Hàm chọn và tải ảnh
  Future<void> _pickAndUploadImage(ImageSource source, String fieldToUpdate, String storagePath) async {
     if (!_isEditing) return; // Chỉ cho phép khi đang sửa

     final ImagePicker picker = ImagePicker();
     try {
        final XFile? image = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1024);
        if (image == null) return; // Người dùng hủy
        
        File imageFile = File(image.path);
        if (mounted) setState(() => _isSaving = true); // Hiển thị loading

        // Tải ảnh lên Storage
        String downloadUrl = await _userService.uploadImage(imageFile, storagePath);

        // Cập nhật link ảnh vào Firestore
        await _userService.updateUserData({ fieldToUpdate: downloadUrl });

        if (mounted) {
           setState(() {
              if (fieldToUpdate == 'avatarUrl') _avatarUrl = downloadUrl;
              if (fieldToUpdate == 'coverUrl') _coverUrl = downloadUrl;
           });
           _showSnack("Cập nhật ảnh thành công!");
        }
     } catch (e) {
        if (mounted) _showError("Tải ảnh thất bại: ${e.toString()}");
     } finally {
        if (mounted) setState(() => _isSaving = false);
     }
  }

  // Hàm lưu Tên và Tiểu sử
  Future<void> _saveProfile() async {
     FocusScope.of(context).unfocus(); // Đóng bàn phím
     if (mounted) setState(() { _isSaving = true; _isEditing = false; }); // Tắt chế độ Edit

     try {
       Map<String, dynamic> dataToUpdate = {
         'name': _nameController.text.trim(),
         'bio': _bioController.text.trim(),
         // 'name_lowercase' sẽ được cập nhật tự động bên trong _userService.updateUserData
       };
       await _userService.updateUserData(dataToUpdate);
       if (mounted) _showSnack("Cập nhật thông tin thành công!");
     } catch (e) {
        if (mounted) _showError("Lỗi lưu thông tin: ${e.toString()}");
        if (mounted) setState(() => _isEditing = true); // Bật lại Edit nếu lỗi
     } finally {
       if (mounted) setState(() => _isSaving = false);
     }
  }

  // Hàm hiển thị hộp thoại xác nhận đăng xuất
  void _showLogoutConfirm() {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text('Đăng xuất', style: TextStyle(color: Colors.red.shade700)),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Đóng dialog
              try {
                // Gọi AuthService để đăng xuất
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
                // StreamBuilder trong main.dart sẽ tự động chuyển về LoginScreen
              } catch (e) {
                 _showError("Lỗi đăng xuất: ${e.toString()}");
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Không có AppBar
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack( // Sử dụng Stack để xếp chồng các lớp
             children: [
                // Lớp 1: Nội dung có thể cuộn
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // --- Cover + Avatar ---
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Ảnh bìa
                          GestureDetector(
                            onTap: _isEditing ? () => _pickAndUploadImage(ImageSource.gallery, 'coverUrl', 'covers') : null,
                            child: Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                image: _coverUrl != null && _coverUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_coverUrl!),
                                        fit: BoxFit.cover,
                                        onError: (error, stackTrace) {
                                           debugPrint("Lỗi tải ảnh bìa: $error");
                                        },
                                      )
                                    : const DecorationImage(
                                         image: AssetImage("assets/cover.jpg"), // Ảnh bìa mặc định
                                         fit: BoxFit.cover,
                                      ),
                                gradient: _coverUrl == null || _coverUrl!.isEmpty
                                    ? const LinearGradient(
                                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                              ),
                              child: _isEditing ? Container(
                                 color: Colors.black.withOpacity(0.3),
                                 child: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 40)
                              ) : null,
                            ),
                          ),
                          // Avatar
                          Positioned(
                            bottom: -50,
                            child: GestureDetector(
                               onTap: _isEditing ? () => _pickAndUploadImage(ImageSource.gallery, 'avatarUrl', 'avatars') : null,
                               child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                   Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 4),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))]
                                      ),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                            ? NetworkImage(_avatarUrl!)
                                            : const AssetImage("assets/avatar.png") as ImageProvider,
                                        backgroundColor: Colors.grey.shade300,
                                      ),
                                   ),
                                   if (_isEditing)
                                      Container(
                                         width: 108,
                                         height: 108,
                                         decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(0.3)
                                         ),
                                         child: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 30),
                                      ),
                                 ],
                               ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),

                      // --- Thông tin (Tên, Bio) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          readOnly: !_isEditing,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            border: _isEditing ? const UnderlineInputBorder() : InputBorder.none,
                            hintText: "Tên hiển thị",
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 24.0),
                         child: TextField(
                           controller: _bioController,
                           textAlign: TextAlign.center,
                           readOnly: !_isEditing,
                           style: TextStyle(color: Colors.grey[700], fontSize: 15, fontStyle: FontStyle.italic),
                           decoration: InputDecoration(
                             border: _isEditing ? const UnderlineInputBorder() : InputBorder.none,
                             hintText: "Tiểu sử...",
                           ),
                           maxLines: null,
                         ),
                      ),
                      const SizedBox(height: 20),

                      // --- Menu quản lý ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildInfoTile(Icons.phone_outlined, _phoneNumber.isNotEmpty ? _phoneNumber : "Chưa cập nhật SĐT", "Số điện thoại"),
                            _buildMenuItem(Icons.article_outlined, "Quản lý bài viết", "Xem các bài viết của bạn", onTap: () {
                               _showSnack("Chức năng Quản lý bài viết (chưa thực hiện)");
                            }),
                            _buildMenuItem(Icons.settings_outlined, "Cài đặt", "Cài đặt tài khoản & quyền riêng tư", onTap: () {
                               _showSnack("Chức năng Cài đặt (chưa thực hiện)");
                            }),
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              color: Colors.red.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Icon(Icons.logout, color: Colors.red.shade700),
                                title: Text('Đăng xuất', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500)),
                                onTap: _showLogoutConfirm,
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                
                // Lớp 2: Nút Edit/Save nổi
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea( 
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildEditSaveButton(), 
                    ),
                  ),
                ),

                // Lớp 3: Lớp phủ Loading khi đang lưu
                if (_isSaving)
                   Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                         child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               CircularProgressIndicator(color: Colors.white),
                               SizedBox(height: 10),
                               Text('Đang lưu...', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ],
                         ),
                      ),
                   ),
             ],
          ),
    );
  }

  // === HÀM HELPER CHO NÚT EDIT/SAVE ===
  Widget _buildEditSaveButton() {
    final ButtonStyle buttonStyle = IconButton.styleFrom(
      backgroundColor: Colors.black.withOpacity(0.4),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(10),
    );

    if (_isEditing) {
      return IconButton(
        icon: const Icon(Icons.check_rounded),
        tooltip: 'Lưu',
        style: buttonStyle,
        onPressed: _isSaving ? null : _saveProfile,
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Chỉnh sửa',
        style: buttonStyle,
        onPressed: () => setState(() => _isEditing = true),
      );
    }
  }

  // --- Các hàm Helper còn lại ---

  // Widget hiển thị thông tin (Chỉ xem)
  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
     return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shadowColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade600),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ),
    );
  }

  // Widget xây dựng menu item (có thể nhấn)
  Widget _buildMenuItem(IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1.5,
      shadowColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // === SỬA LỖI TẠI ĐÂY (Dòng 346 cũ) ===
      // ListTile là một widget có constructor, không phải là một hàm.
      // Nó được gọi BÊN TRONG child, không phải là một tham số.
      child: ListTile( 
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
      // ==================================
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

