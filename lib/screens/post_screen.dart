import 'dart:io';
import 'package:flutter/material.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'widgets/post_card.dart';
import 'story_detail_screen.dart';
import 'post_detail_screen.dart';

class PostScreen extends StatefulWidget {
  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final List<Map<String, String?>> posts = [
    {"userName": "Nguyen Xuan", "text": "Bài viết mẫu", "image": null}
  ];

  final List<Map<String, String?>> stories = [
    {"text": "Tin mẫu", "image": null}
  ];

  void _navigateToCreatePost() async {
    final newPost = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen()),
    );
    if (newPost != null) {
      setState(() => posts.insert(0, newPost));
    }
  }

  void _navigateToCreateStory() async {
    final newStory = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateStoryScreen()),
    );
    if (newStory != null) {
      setState(() => stories.insert(0, newStory));
    }
  }

  Widget _buildStoryItem(Map<String, String?> story, int index) {
    final imagePath = story["image"];
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryDetailScreen(
              stories: stories,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Nền story
          Container(
            width: 120,
            height: 180,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[300],
              image: imagePath != null && File(imagePath).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.25), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          // Tên tin ở góc dưới trái
          Positioned(
            left: 8,
            bottom: 8,
            child: Text(
              story["text"] ?? "",
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),

          // Ảnh đại diện ở góc dưới phải
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: imagePath != null && File(imagePath).existsSync()
                    ? DecorationImage(image: FileImage(File(imagePath)), fit: BoxFit.cover)
                    : const DecorationImage(
                        image: AssetImage('assets/default_avatar.png'),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // "Bạn đang nghĩ gì?" + nút tạo story
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToCreatePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.edit, color: Colors.grey),
                            SizedBox(width: 10),
                            Text("Bạn đang nghĩ gì?", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _navigateToCreateStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Stories + Posts
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: 1 + posts.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Stories
                    return SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: stories.length + 1,
                        itemBuilder: (context, sIndex) {
                          if (sIndex == 0) {
                            return GestureDetector(
                              onTap: _navigateToCreateStory,
                              child: Container(
                                width: 120,
                                height: 180,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.grey[400]!),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, color: Colors.black54, size: 28),
                                ),
                              ),
                            );
                          }
                          return _buildStoryItem(stories[sIndex - 1], sIndex - 1);
                        },
                      ),
                    );
                  } else {
                    final post = posts[index - 1];
                    return PostCard(
                      userName: post["userName"] ?? "Người dùng",
                      text: post["text"],
                      imagePath: post["image"],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              userName: post["userName"] ?? "Người dùng",
                              text: post["text"],
                              imagePath: post["image"],
                            ),
                          ),
                        );
                      },
                      onDelete: () {
                        setState(() {
                          posts.removeAt(index - 1);
                        });
                      },
                      onHideUser: () {
                        setState(() {
                          final user = post["userName"];
                          posts.removeWhere((p) => p["userName"] == user);
                        });
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
