import 'dart:io';
import 'package:flutter/material.dart';

class PostCard extends StatefulWidget {
  final String userName;
  final String? text;
  final String? imagePath;
  final String timeAgo;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onHideUser;

  const PostCard({
    Key? key,
    required this.userName,
    this.text,
    this.imagePath,
    this.timeAgo = "1 giờ trước",
    this.onTap,
    this.onDelete,
    this.onHideUser,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  final TextEditingController _commentController = TextEditingController();
  final List<String> comments = [];

  void _toggleLike() {
    setState(() => isLiked = !isLiked);
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      comments.insert(0, _commentController.text.trim());
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với menu 3 chấm
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(widget.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(widget.timeAgo),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    widget.onDelete?.call();
                  } else if (value == 'hide') {
                    widget.onHideUser?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa bài viết'),
                  ),
                  const PopupMenuItem(
                    value: 'hide',
                    child: Text('Ẩn bài viết của người này'),
                  ),
                ],
              ),
            ),

            // Text
            if (widget.text != null && widget.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(widget.text!, style: const TextStyle(fontSize: 16)),
              ),

            // Image
            if (widget.imagePath != null && File(widget.imagePath!).existsSync())
              Image.file(File(widget.imagePath!),
                  fit: BoxFit.cover, width: double.infinity),

            // Action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red),
                    onPressed: _toggleLike,
                  ),
                  const SizedBox(width: 4),
                  Text(isLiked ? "1" : "0"),
                  const SizedBox(width: 16),
                  const Icon(Icons.comment, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text("${comments.length}"),
                  const SizedBox(width: 16),
                  const Icon(Icons.share, color: Colors.blueGrey),
                ],
              ),
            ),

            // Comment input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "Viết bình luận...",
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),

            // Comment list
            if (comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: comments
                      .map((cmt) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(cmt),
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
