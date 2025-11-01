import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class StoryDetailScreen extends StatefulWidget {
  final List<Map<String, String?>> stories;
  final int initialIndex;

  const StoryDetailScreen({Key? key, required this.stories, this.initialIndex = 0})
      : super(key: key);

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late PageController _pageController;
  late Timer _timer;
  int _currentIndex = 0;

  Map<int, String> reactions = {}; // lưu cảm xúc từng story

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _startAutoNext();
  }

  void _startAutoNext() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentIndex < widget.stories.length - 1) {
        _currentIndex++;
        _pageController.animateToPage(_currentIndex,
            duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      } else {
        Navigator.pop(context);
      }
    });
  }

  void _addReaction(String reaction) {
    setState(() {
      reactions[_currentIndex] = reaction;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildReactions() {
    return Positioned(
      bottom: 60,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _addReaction('❤️')),
          IconButton(
              icon: const Icon(Icons.sentiment_satisfied, color: Colors.yellow),
              onPressed: () => _addReaction('😆')),
          IconButton(
              icon: const Icon(Icons.thumb_up, color: Colors.blue),
              onPressed: () => _addReaction('👍')),
          IconButton(
              icon: const Icon(Icons.tag_faces, color: Colors.orange),
              onPressed: () => _addReaction('😍')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final imagePath = story["image"];
              final timeAgo = story["time"] ?? "1 giờ trước";

              return Stack(
                children: [
                  // Hình nền story
                  if (imagePath != null && File(imagePath).existsSync())
                    SizedBox.expand(
                        child: Image.file(File(imagePath), fit: BoxFit.cover)),
                  // Overlay gradient để chữ rõ hơn
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  // Thông tin user + thời gian
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(story["userName"] ?? "Người dùng",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(timeAgo,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Text story
                  if (story["text"] != null)
                    Positioned(
                      bottom: 150,
                      left: 16,
                      right: 16,
                      child: Text(
                        story["text"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  // Reaction nếu đã chọn
                  if (reactions.containsKey(index))
                    Positioned(
                      bottom: 120,
                      left: 16,
                      child: Text(
                        reactions[index]!,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  // Thanh tiến trình story
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: List.generate(
                        widget.stories.length,
                        (i) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 5,
                            decoration: BoxDecoration(
                              color: i <= _currentIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Nút thả cảm xúc
                  _buildReactions(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
