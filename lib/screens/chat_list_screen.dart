import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'group_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String searchQuery;

  const ChatListScreen({super.key, required this.searchQuery});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  OverlayEntry? _overlayEntry;
  Timer? _autoHideTimer;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeIntl();
  }

  Future<void> _initializeIntl() async {
    try {
      DateFormat.E('vi_VN').format(DateTime.now());
    } catch (e) {
      debugPrint("Lỗi khởi tạo locale 'vi_VN': $e. Dùng locale mặc định.");
    }
  }

  // 🚀 HÀM GHIM / BỎ GHIM CHAT
  Future<void> _togglePinChat(String chatRoomId, String displayName) async {
    try {
      final userId = currentUser!.uid;
      final roomRef =
          FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId);
      final doc = await roomRef.get();
      final data = doc.data() ?? {};
      final pinnedBy = Map<String, dynamic>.from(data['pinnedBy'] ?? {});
      final isPinned = pinnedBy[userId] == true;
      pinnedBy[userId] = !isPinned;
      await roomRef.update({'pinnedBy': pinnedBy});

      _showSnack(
        isPinned
            ? "Đã bỏ ghim trò chuyện với $displayName."
            : "Đã ghim trò chuyện với $displayName lên đầu.",
      );
    } catch (e) {
      debugPrint("Lỗi ghim trò chuyện: $e");
      _showSnack("Không thể ghim trò chuyện.", isError: true);
    }
  }

  void _removeOverlay() {
    _autoHideTimer?.cancel();
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.remove();
    }
    _overlayEntry = null;
  }

  void _showPopupMenu(BuildContext context, Offset position, int index,
      String displayName, String chatRoomId, bool isGroup) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: 25.0.clamp(0.0, MediaQuery.of(context).size.width - 255.0),
            top: (position.dy -
                    MediaQuery.of(context).viewInsets.bottom -
                    200)
                .clamp(MediaQuery.of(context).padding.top + 10, double.infinity),
            child: _buildPopupMenu(
                context, index, displayName, chatRoomId, isGroup),
          ),
        ],
      ),
    );
    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
      _autoHideTimer = Timer(const Duration(seconds: 4), _removeOverlay);
    }
  }

  Widget _buildPopupMenu(BuildContext context, int index, String displayName,
      String chatRoomId, bool isGroup) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: Icons.mark_chat_unread_outlined,
              color: Colors.blueAccent,
              label: "Đánh dấu là chưa đọc",
              onTap: () {
                _removeOverlay();
                _showSnack("Đã đánh dấu '$displayName' là chưa đọc.");
              },
            ),
            // 🔥 Thay chức năng ghim ở đây
            _buildMenuItem(
              icon: Icons.push_pin_outlined,
              color: Colors.orangeAccent.shade700,
              label: "Ghim / Bỏ ghim",
              onTap: () async {
                _removeOverlay();
                await _togglePinChat(chatRoomId, displayName);
              },
            ),
            _buildMenuItem(
              icon: Icons.notifications_off_outlined,
              color: Colors.deepPurpleAccent,
              label: "Tắt thông báo",
              onTap: () {
                _removeOverlay();
                _showSnack("Đã tắt thông báo của $displayName.");
              },
            ),
            if (!isGroup)
              _buildMenuItem(
                icon: Icons.visibility_off_outlined,
                color: Colors.grey.shade600,
                label: "Ẩn trò chuyện",
                onTap: () {
                  _removeOverlay();
                  _showSnack("Đã ẩn trò chuyện với $displayName.");
                },
              ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildMenuItem(
              icon: Icons.delete_outline,
              color: Colors.redAccent,
              label: isGroup ? "Rời nhóm & Xóa" : "Xóa trò chuyện",
              onTap: () async {
                _removeOverlay();
                bool? confirmDelete = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(isGroup ? 'Xác nhận rời nhóm' : 'Xác nhận xóa'),
                    content: Text(isGroup
                        ? 'Bạn có chắc muốn rời khỏi nhóm "$displayName"?'
                        : 'Bạn có chắc muốn xóa cuộc trò chuyện với $displayName?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(isGroup ? 'Rời nhóm' : 'Xóa',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmDelete == true) {
                  try {
                    if (isGroup) {
                      await FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(chatRoomId)
                          .delete();
                      _showSnack("Đã rời/xóa nhóm $displayName");
                    } else {
                      final messagesRef = FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(chatRoomId)
                          .collection('messages');
                      final messagesSnapshot = await messagesRef.get();
                      WriteBatch batch = FirebaseFirestore.instance.batch();
                      for (var doc in messagesSnapshot.docs) {
                        batch.delete(doc.reference);
                      }
                      await batch.commit();
                      await FirebaseFirestore.instance
                          .collection('chat_rooms')
                          .doc(chatRoomId)
                          .delete();
                      _showSnack("Đã xóa trò chuyện.");
                    }
                  } catch (e) {
                    debugPrint("Lỗi xóa/rời nhóm $chatRoomId: $e");
                    _showSnack("Thao tác thất bại. Vui lòng thử lại.",
                        isError: true);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
      onTap: onTap,
      minLeadingWidth: 0,
    );
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin:
            const EdgeInsets.only(bottom: 80.0, left: 16.0, right: 16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text('Lỗi: Người dùng chưa đăng nhập.')));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('users', arrayContains: currentUser!.uid)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Lỗi tải ChatList: ${snapshot.error}");
          return const Center(child: Text('Không thể tải danh sách chat.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                widget.searchQuery.isNotEmpty
                    ? 'Không có cuộc trò chuyện nào khớp.'
                    : 'Chưa có cuộc trò chuyện nào.\nNhấn nút (+) để tìm bạn hoặc tạo nhóm.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          );
        }

        final chatRooms = snapshot.data!.docs;
        final userId = currentUser!.uid;

        // 🔥 Sắp xếp: ghim trước, sau đó theo lastMessageTime
        final sortedRooms = [...chatRooms];
        sortedRooms.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPinned = (aData['pinnedBy'] ?? {})[userId] == true;
          final bPinned = (bData['pinnedBy'] ?? {})[userId] == true;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        final filteredRooms = sortedRooms.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final bool isGroup = data['isGroup'] ?? false;
            String displayName = '';
            if (isGroup) {
              displayName = data['groupName'] ?? 'Nhóm';
            } else {
              final userNames =
                  data['userNames'] as Map<String, dynamic>? ?? {};
              userNames.forEach((uid, name) {
                if (uid != currentUser!.uid) displayName = name.toString();
              });
            }
            return displayName
                .toLowerCase()
                .contains(widget.searchQuery.toLowerCase());
          } catch (e) {
            debugPrint("Lỗi xử lý phòng chat ${doc.id}: $e");
            return false;
          }
        }).toList();

        return ListView.separated(
          itemCount: filteredRooms.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: 80, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final roomDoc = filteredRooms[index];
            final chatRoomId = roomDoc.id;
            try {
              final data = roomDoc.data() as Map<String, dynamic>;
              final bool isGroup = data['isGroup'] ?? false;
              final Map<String, dynamic> userNames = data['userNames'] ?? {};
              final Map<String, dynamic> userAvatars = data['userAvatars'] ?? {};
              final bool isPinned =
                  (data['pinnedBy'] ?? {})[currentUser!.uid] == true;

              String displayName = '';
              String? displayAvatarUrl;
              String friendUid = '';

              if (isGroup) {
                displayName = data['groupName'] ?? 'Nhóm';
                displayAvatarUrl = data['groupAvatarUrl'];
              } else {
                userNames.forEach((uid, name) {
                  if (uid != currentUser!.uid) {
                    friendUid = uid;
                    displayName = name.toString();
                    displayAvatarUrl = userAvatars[uid]?.toString();
                  }
                });
              }

              String lastMessage = data['lastMessage'] ?? '...';
              Timestamp? lastMessageTime = data['lastMessageTime'] as Timestamp?;

              return GestureDetector(
                onLongPressStart: (details) => _showPopupMenu(
                    context,
                    details.globalPosition,
                    index,
                    displayName,
                    chatRoomId,
                    isGroup),
                child: InkWell(
                  onTap: () {
                    if (isGroup) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(
                            chatRoomId: chatRoomId,
                            groupName: displayName,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            friendUid: friendUid,
                            friendName: displayName,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage:
                              (displayAvatarUrl != null && displayAvatarUrl!.isNotEmpty)
                                  ? NetworkImage(displayAvatarUrl!)
                                  : null,
                          backgroundColor: Colors
                              .accents[index % Colors.accents.length]
                              .withValues(alpha: 0.2),
                          child: (displayAvatarUrl == null ||
                                  displayAvatarUrl!.isEmpty)
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : (isGroup ? 'N' : '?'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors
                                        .accents[index % Colors.accents.length],
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isPinned)
                                    const Icon(Icons.push_pin,
                                        color: Colors.orangeAccent, size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastMessage,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lastMessageTime != null
                                  ? _formatTimestamp(lastMessageTime.toDate())
                                  : '',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } catch (e) {
              debugPrint("Lỗi hiển thị phòng chat ${roomDoc.id}: $e");
              return Container(
                padding: const EdgeInsets.all(16),
                child: Text('Lỗi tải dữ liệu chat: ${roomDoc.id}',
                    style: const TextStyle(color: Colors.red)),
              );
            }
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(time.year, time.month, time.day);

    try {
      if (dateToCheck == today) {
        return DateFormat.Hm().format(time);
      } else if (dateToCheck == yesterday) {
        return 'Hôm qua';
      } else if (now.difference(time).inDays < 7) {
        return DateFormat.E('vi_VN').format(time);
      } else {
        return DateFormat('dd/MM/yy').format(time);
      }
    } catch (e) {
      debugPrint("Lỗi format thời gian: $e");
      return "${time.day}/${time.month}";
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }
}
