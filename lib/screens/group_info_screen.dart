// ... (code initState, dispose, _showSnack, _showError, _handleLeaveGroup giữ nguyên) ...
// aikaneko:ignore
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/user_service.dart'; // Import UserService
import 'chat_screen.dart'; // Để mở chat 1-1
import 'search_user_screen.dart'; // Để mở màn hình tìm/thêm bạn
import 'user_info_screen.dart'; // Để mở trang cá nhân người dùng

class GroupInfoScreen extends StatefulWidget {
  final String chatRoomId;

  const GroupInfoScreen({super.key, required this.chatRoomId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    _showSnack(message, isError: true);
  }

  Future<void> _showEditGroupDialog(
    String currentName,
    String? currentAvatarUrl,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    String? newAvatarPath;
    String? newAvatarUrl = currentAvatarUrl;

    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Chỉnh sửa thông tin nhóm'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              setDialogState(() {
                                newAvatarPath = image.path;
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage:
                                    newAvatarPath != null
                                        ? FileImage(File(newAvatarPath!))
                                        : (newAvatarUrl != null
                                            ? NetworkImage(newAvatarUrl!)
                                                as ImageProvider
                                            : null),
                                backgroundColor: Colors.grey.shade200,
                                child:
                                    (newAvatarPath == null &&
                                            newAvatarUrl == null)
                                        ? const Icon(
                                          Icons.camera_alt,
                                          size: 40,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên nhóm',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) {
                          _showError('Tên nhóm không được để trống');
                          return;
                        }
                        Navigator.pop(ctx, {
                          'name': newName,
                          'avatarPath': newAvatarPath,
                        });
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
          ),
    ).then((result) async {
      if (result != null) {
        String? updatedAvatarUrl = newAvatarUrl;

        try {
          // Upload ảnh mới nếu có
          if (result['avatarPath'] != null) {
            final File imageFile = File(result['avatarPath']);
            final ref = FirebaseStorage.instance
                .ref()
                .child('group_avatars')
                .child('${widget.chatRoomId}.jpg');

            await ref.putFile(imageFile);
            updatedAvatarUrl = await ref.getDownloadURL();
          }

          // Cập nhật thông tin nhóm
          await FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(widget.chatRoomId)
              .update({
                'groupName': result['name'],
                if (updatedAvatarUrl != null)
                  'groupAvatarUrl': updatedAvatarUrl,
              });

          if (mounted) _showSnack('Đã cập nhật thông tin nhóm');
        } catch (e) {
          if (mounted) _showError('Lỗi cập nhật: ${e.toString()}');
        }
      }
    });
  }

  Future<void> _handleLeaveGroup() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Xác nhận rời nhóm'),
            content: const Text('Bạn có chắc chắn muốn rời khỏi nhóm này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Rời nhóm',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _userService.leaveGroup(widget.chatRoomId);
        if (mounted) {
          _showSnack("Đã rời nhóm thành công.");
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst("Exception: ", ""));
      }
    }
  }
  // aikaneko:ignore

  // Hàm xử lý Thêm thành viên (ĐÃ SỬA)
  void _navigateToAddMembers(List<dynamic> memberUids) {
    final List<String> currentMemberIds =
        memberUids.map((uid) => uid.toString()).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchUserScreen(
              chatRoomIdToAddTo: widget.chatRoomId,
              currentGroupMembers: currentMemberIds,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Lỗi: Người dùng chưa đăng nhập.')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userService.getGroupStream(widget.chatRoomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Đang tải...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context))
              Navigator.of(context).pop();
          });
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Không tìm thấy nhóm.')),
          );
        }
        if (snapshot.hasError) {
          debugPrint("Lỗi tải group info: ${snapshot.error}");
          return Scaffold(
            appBar: AppBar(title: const Text('Thông tin nhóm')),
            body: const Center(child: Text('Lỗi tải thông tin nhóm.')),
          );
        }

        final groupData = snapshot.data!.data() as Map<String, dynamic>;
        final String groupName = groupData['groupName'] ?? 'Tên nhóm';
        final String? groupAvatarUrl = groupData['groupAvatarUrl'];
        final List<dynamic> memberUids =
            groupData['users'] ?? [];
        final Map<String, dynamic> userNames = groupData['userNames'] ?? {};
        final Map<String, dynamic> userAvatars = groupData['userAvatars'] ?? {};
        final List<dynamic> adminUids = groupData['adminUids'] ?? [];
        final bool isAdmin = adminUids.contains(currentUser!.uid);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Thông tin nhóm'),
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
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: isAdmin
                      ? () => _showEditGroupDialog(groupName, groupAvatarUrl)
                      : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            groupAvatarUrl != null ? NetworkImage(groupAvatarUrl) : null,
                        backgroundColor: Colors.grey.shade200,
                        child:
                            groupAvatarUrl == null
                                ? const Icon(
                                  Icons.group,
                                  size: 50,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                      if (isAdmin)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: isAdmin
                      ? () => _showEditGroupDialog(groupName, groupAvatarUrl)
                      : null,
                  child: Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${memberUids.length} thành viên',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(context, Icons.message, 'Nhắn tin', () {
                      Navigator.pop(context);
                    }),
                    if (isAdmin)
                      _buildActionButton(
                        context,
                        Icons.person_add,
                        'Thêm',
                        () => _navigateToAddMembers(memberUids),
                      ),
                    _buildActionButton(context, Icons.search, 'Tìm kiếm', () {
                      _showSnack("Chức năng tìm kiếm tin nhắn chưa có.");
                    }),
                    _buildActionButton(
                      context,
                      Icons.notifications,
                      'Tắt TB',
                      () {
                        _showSnack("Chức năng tắt thông báo chưa có.");
                      },
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thành viên (${memberUids.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin)
                        TextButton(
                          onPressed: () => _navigateToAddMembers(memberUids),
                          child: const Text('Thêm thành viên'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: memberUids.length,
                  itemBuilder: (context, index) {
                    final uid = memberUids[index] as String;
                    final name = userNames[uid] ?? 'Người dùng';
                    final avatarUrl = userAvatars[uid] as String?;
                    final bool isMemberAdmin = adminUids.contains(uid);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        backgroundColor: Colors.grey.shade200,
                        child:
                            (avatarUrl == null || avatarUrl.isEmpty)
                                ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                )
                                : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle:
                          isMemberAdmin
                              ? const Text(
                                'Quản trị viên nhóm',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              )
                              : null,
                      trailing:
                          (uid == currentUser!.uid)
                              ? const Text(
                                '(Bạn)',
                                style: TextStyle(color: Colors.grey),
                              )
                              : isAdmin
                              ? IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey.shade500,
                                ),
                                onPressed: () {
                                  _showMemberOptions(
                                    context,
                                    uid,
                                    name,
                                    isMemberAdmin,
                                  );
                                },
                              )
                              : null,
                      onTap: () {
                        if (uid != currentUser!.uid) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => UserInfoScreen(friendUid: uid),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                const Divider(height: 30, thickness: 1),

                ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.red.shade700),
                  title: Text(
                    'Rời nhóm',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _handleLeaveGroup,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
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
              color: Colors.blue.withAlpha(26),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  void _showMemberOptions(
    BuildContext context,
    String memberUid,
    String memberName,
    bool isMemberAdmin,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.message_outlined,
                color: Colors.blueAccent,
              ),
              title: Text('Nhắn tin cho $memberName'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChatScreen(
                          friendUid: memberUid,
                          friendName: memberName,
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.green),
              title: const Text('Xem trang cá nhân'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserInfoScreen(friendUid: memberUid),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isMemberAdmin ? Icons.shield_outlined : Icons.shield,
                color: Colors.orange.shade700,
              ),
              title: Text(
                isMemberAdmin
                    ? 'Hủy quyền Quản trị viên'
                    : 'Chỉ định làm Quản trị viên',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _toggleAdminRole(memberUid, isMemberAdmin);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.remove_circle_outline,
                color: Colors.red.shade700,
              ),
              title: Text(
                'Xóa khỏi nhóm',
                style: TextStyle(color: Colors.red.shade700),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Xác nhận"),
                    content: Text("Bạn có chắc chắn muốn xóa $memberName khỏi nhóm không?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Hủy"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Xóa", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _removeMemberFromGroup(memberUid, memberName);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Future<void> _toggleAdminRole(String memberUid, bool isMemberAdmin) async {
    try {
      await _userService.setAdminStatus(widget.chatRoomId, memberUid, !isMemberAdmin);
      _showSnack(!isMemberAdmin
          ? 'Đã chỉ định quyền Quản trị viên cho người dùng'
          : 'Đã hủy quyền Quản trị viên của người dùng');
    } catch (e) {
      _showError('Lỗi: $e');
    }
  }

  Future<void> _removeMemberFromGroup(String memberUid, String memberName) async {
    try {
      await _userService.removeMemberFromGroupWithAdminCheck(widget.chatRoomId, memberUid);
      _showSnack('Đã xóa $memberName khỏi nhóm');
    } catch (e) {
      _showError('Lỗi: $e');
    }
  }
}
// aikaneko:ignore
