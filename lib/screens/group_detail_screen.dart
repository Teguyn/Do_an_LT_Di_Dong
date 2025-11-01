import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Cho Clipboard
import '../screens/widgets/messages_widget.dart';
import 'group_info_screen.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final String chatRoomId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.chatRoomId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _currentUserName = 'Bạn';
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  DocumentSnapshot? _editingMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    if (currentUser == null) return;
    try {
      final userDoc = await _userService.getUserData(currentUser!.uid);
      if (userDoc != null && userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['name'] ?? 'Bạn';
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải thông tin user: $e");
    }
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
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
        'text': messageText,
        'createdAt': Timestamp.now(),
        'senderId': currentUser!.uid,
        'senderName': _currentUserName,
        'isRevoked': false,
        'reactions': {},
      });
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .update({
        'lastMessage': '$_currentUserName: $messageText',
        'lastMessageTime': Timestamp.now(),
      });
      debugPrint("Đã gửi tin nhắn nhóm!");
    } catch (e) {
      debugPrint("Lỗi gửi tin nhắn nhóm: $e");
      if (mounted) _showError('Không thể gửi tin nhắn. Vui lòng thử lại.');
    }
  }

  void _onMessageLongPress(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final bool isMyMessage = data['senderId'] == currentUser?.uid;
    final bool isRevoked = data['isRevoked'] ?? false;
    final bool isPinned = data.containsKey('isPinned') ? data['isPinned'] : false;

    if (isRevoked) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                  leading: const Icon(Icons.copy_outlined, color: Colors.blueAccent),
                  title: const Text('Sao chép văn bản'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: data['text']));
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
                      _chatService
                          .unpinMessage(widget.chatRoomId, messageDoc.id)
                          .catchError((e) => _showError(e.toString()));
                    } else {
                      _chatService
                          .pinMessage(widget.chatRoomId, messageDoc)
                          .catchError((e) => _showError(e.toString()));
                    }
                  },
                ),
                if (isMyMessage)
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: Colors.grey.shade700),
                    title: const Text('Chỉnh sửa'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startEditing(messageDoc);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.grey.shade700),
                  title: const Text('Xóa (chỉ ở phía bạn)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _chatService
                        .deleteMessageForMe(widget.chatRoomId, messageDoc.id)
                        .catchError((e) => _showError(e.toString()));
                  },
                ),
                if (isMyMessage)
                  ListTile(
                    leading: Icon(Icons.undo_rounded, color: Colors.red.shade700),
                    title: Text(
                      'Thu hồi tin nhắn',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _chatService
                          .revokeMessage(widget.chatRoomId, messageDoc.id)
                          .catchError((e) => _showError(e.toString()));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
                  .reactToMessage(widget.chatRoomId, messageId, emoji)
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
      _controller.text = messageDoc['text'];
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
    final String originalText = _editingMessage!['text'];
    _cancelEditing();
    if (newText == originalText) return;
    try {
      await _chatService.editMessage(widget.chatRoomId, messageId, newText);
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Widget _buildPinnedMessageBar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userService.getGroupStream(widget.chatRoomId),
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
                offset: const Offset(0, 1),
              )
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
                      .unpinMessage(widget.chatRoomId, pinnedMessage['messageId'])
                      .catchError((e) => _showError(e.toString()));
                },
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
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
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Thông tin nhóm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(
                    chatRoomId: widget.chatRoomId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildPinnedMessageBar(),
          Expanded(
            child: MessagesWidget(
              chatRoomId: widget.chatRoomId,
              currentUserId: currentUser!.uid,
              friendName: widget.groupName,
              onSendGreeting: () =>
                  _sendMessage(customMessage: "Chào cả nhóm! 👋"),
              onMessageLongPress: _onMessageLongPress,
              isGroupChat: true,
            ),
          ),
          if (_editingMessage != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    icon: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade700),
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
              onPressed: () {}, // ✅ Bổ sung dòng này
              tooltip: 'Gửi ảnh',
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                border: Border.all(
                    color: _editingMessage != null
                        ? Colors.blueAccent
                        : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _controller,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: _editingMessage != null
                      ? 'Sửa tin nhắn...'
                      : 'Nhắn tin nhóm...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                minLines: 1,
              ),
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
                  color: _controller.text.trim().isEmpty
                      ? Colors.white54
                      : Colors.white,
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
