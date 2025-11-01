import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Cho debugPrint
import 'package:flutter/services.dart'; // Cho Clipboard

// Import
import '../screens/widgets/messages_widget.dart'; // Widget danh sách tin nhắn
import 'user_info_screen.dart';      // Màn hình thông tin
import 'chat_options_screen.dart';   // Màn hình tùy chọn chat
import '../services/chat_service.dart'; // Service chat nâng cao
import '../services/user_service.dart';  // Service lấy thông tin user

class ChatScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late String _chatRoomId;
  String _currentUserName = 'Bạn';

  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  DocumentSnapshot? _editingMessage;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _chatRoomId = _getChatRoomId(currentUser!.uid, widget.friendUid);
      _loadCurrentUserInfo();
    }
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final userDoc = await _userService.getUserData(currentUser!.uid);
      if (userDoc != null && userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['name'] ?? 'Bạn';
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy thông tin user hiện tại: $e");
    }
  }

  String _getChatRoomId(String uid1, String uid2) {
    List<String> userIds = [uid1, uid2]..sort();
    return userIds.join('_');
  }

  void _sendMessage({String? customMessage}) async {
    if (_editingMessage != null) {
      _handleEditMessage();
      return;
    }

    final messageText = customMessage ?? _controller.text.trim();
    if (messageText.isEmpty || currentUser == null) return;

    FocusScope.of(context).unfocus();
    if (customMessage == null) _controller.clear();

    try {
      final chatRoomRef =
          FirebaseFirestore.instance.collection('chat_rooms').doc(_chatRoomId);
      final messagesRef = chatRoomRef.collection('messages');

      await chatRoomRef.set({
        'lastMessage': messageText,
        'lastMessageTime': Timestamp.now(),
        'users': [currentUser!.uid, widget.friendUid],
        'userNames': {
          currentUser!.uid: _currentUserName,
          widget.friendUid: widget.friendName,
        },
        'isGroup': false,
      }, SetOptions(merge: true));

      await messagesRef.add({
        'text': messageText,
        'createdAt': Timestamp.now(),
        'senderId': currentUser!.uid,
        'receiverId': widget.friendUid,
        'senderName': _currentUserName,
        'isRevoked': false,
        'reactions': {},
      });
      debugPrint("Đã gửi tin nhắn!");
    } catch (e) {
      debugPrint("Lỗi gửi tin nhắn: $e");
      if (mounted) _showError("Không thể gửi tin nhắn.");
    }
  }

  void _onMessageLongPress(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final bool isMyMessage = data['senderId'] == currentUser?.uid;
    final bool isRevoked = data['isRevoked'] ?? false;
    final bool isPinned =
        data.containsKey('isPinned') ? data['isPinned'] : false;

    if (isRevoked) return;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Wrap(
                children: <Widget>[
                  _buildReactionRow(ctx, messageDoc.id),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.copy_outlined, color: Colors.blueAccent),
                    title: const Text('Sao chép văn bản'),
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: data['text'] ?? ''));
                      Navigator.pop(ctx);
                      _showSnack("Đã sao chép!");
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: Colors.orangeAccent.shade700,
                    ),
                    title: Text(isPinned ? 'Bỏ ghim tin nhắn' : 'Ghim tin nhắn'),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (isPinned) {
                        _chatService.unpinMessage(_chatRoomId, messageDoc.id);
                      } else {
                        _chatService.pinMessage(_chatRoomId, messageDoc);
                      }
                    },
                  ),
                  if (isMyMessage)
                    ListTile(
                      leading: Icon(Icons.edit_outlined,
                          color: Colors.grey.shade700),
                      title: const Text('Chỉnh sửa'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startEditing(messageDoc);
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: Colors.grey.shade700),
                    title: const Text('Xóa (chỉ ở phía bạn)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _chatService
                          .deleteMessageForMe(_chatRoomId, messageDoc.id)
                          .catchError((e) => _showError(e.toString()));
                    },
                  ),
                  if (isMyMessage)
                    ListTile(
                      leading: Icon(Icons.undo_rounded,
                          color: Colors.red.shade700),
                      title: Text('Thu hồi tin nhắn',
                          style: TextStyle(color: Colors.red.shade700)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _chatService
                            .revokeMessage(_chatRoomId, messageDoc.id)
                            .catchError((e) => _showError(e.toString()));
                      },
                    ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildReactionRow(BuildContext ctx, String messageId) {
    final List<String> emojis = ['❤️', '😂', '👍', '😢', '😮', '😡'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: emojis.map((emoji) {
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _chatService
                  .reactToMessage(_chatRoomId, messageId, emoji)
                  .catchError((e) => _showError(e.toString()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _startEditing(DocumentSnapshot messageDoc) {
    setState(() {
      _editingMessage = messageDoc;
      _controller.text = messageDoc['text'] ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _controller.clear();
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _handleEditMessage() async {
    final newText = _controller.text.trim();
    if (newText.isEmpty || _editingMessage == null) {
      _cancelEditing();
      return;
    }

    final messageId = _editingMessage!.id;
    _cancelEditing();

    try {
      await _chatService.editMessage(_chatRoomId, messageId, newText);
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Widget _buildPinnedMessageBar() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_chatRoomId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final pinnedMessage = data['pinnedMessage'] as Map<String, dynamic>?;

          if (pinnedMessage == null) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1))
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.push_pin, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${pinnedMessage['senderName']}: ${pinnedMessage['text']}",
                    style: TextStyle(
                        color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _chatService
                        .unpinMessage(_chatRoomId, pinnedMessage['messageId'])
                        .catchError((e) => _showError(e.toString()));
                  },
                )
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text("Vui lòng đăng nhập để chat.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
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
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == "options") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatOptionsScreen(
                      friendUid: widget.friendUid,
                      friendName: widget.friendName,
                      chatRoomId: _chatRoomId,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: "options",
                child: Text("Tùy chọn chat"),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildPinnedMessageBar(),
          Expanded(
            child: MessagesWidget(
              chatRoomId: _chatRoomId,
              currentUserId: currentUser!.uid,
              friendName: widget.friendName,
              onSendGreeting: () =>
                  _sendMessage(customMessage: "Xin chào! 👋"),
              onMessageLongPress: _onMessageLongPress,
            ),
          ),
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang sửa: "${_editingMessage!['text']}"',
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _cancelEditing,
                  )
                ],
              ),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          )
        ],
      ),
      child: Row(
        children: <Widget>[
          if (_editingMessage != null)
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: Colors.red.shade600),
              onPressed: _cancelEditing,
              tooltip: 'Hủy sửa',
            )
          else
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined,
                  color: Theme.of(context).primaryColor),
              onPressed: () {},
              tooltip: 'Gửi ảnh',
            ),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25.0),
                      border: Border.all(
                          color: _editingMessage != null
                              ? Colors.blueAccent
                              : Colors.grey.shade300)),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText:
                          _editingMessage != null ? 'Sửa tin nhắn...' : 'Nhắn tin...',
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    minLines: 1,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8.0),
          Material(
            color: Theme.of(context).primaryColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _controller.text.trim().isEmpty ? null : _sendMessage,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  _editingMessage != null ? Icons.check_rounded : Icons.send,
                  color:
                      _controller.text.trim().isEmpty ? Colors.white54 : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      content: Text(message.replaceFirst("Exception: ", "")),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }
}
