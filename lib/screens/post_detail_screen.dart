import 'dart:io';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatefulWidget {
  final String userName;
  final String? text;
  final String? imagePath;

  const PostDetailScreen({
    Key? key,
    required this.userName,
    this.text,
    this.imagePath,
  }) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool isLiked = false;
  final TextEditingController _commentController = TextEditingController();
  final List<String> comments = [];

  void _toggleLike() => setState(() => isLiked = !isLiked);

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      comments.insert(0, _commentController.text.trim());
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết bài viết")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white)),
              title: Text(widget.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (widget.text != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.text!, style: const TextStyle(fontSize: 16)),
              ),
            if (widget.imagePath != null && File(widget.imagePath!).existsSync())
              Image.file(File(widget.imagePath!), width: double.infinity, fit: BoxFit.cover),
            const Divider(),
            // Action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: _toggleLike,
                  ),
                  const SizedBox(width: 8),
                  Text(isLiked ? "1" : "0"),
                  const SizedBox(width: 16),
                  const Icon(Icons.comment, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text("${comments.length}"),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: _addComment)
                ],
              ),
            ),
            if (comments.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
