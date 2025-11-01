import 'package:flutter/material.dart';

class CallScreen extends StatelessWidget {
  final String name;
  final bool isVideo;

  CallScreen({required this.name, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isVideo ? "Video Call" : "Voice Call")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            SizedBox(height: 20),
            Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(isVideo ? "Đang gọi video..." : "Đang gọi thoại..."),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.call_end),
                  onPressed: () => Navigator.pop(context),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  child: Icon(isVideo ? Icons.videocam : Icons.call),
                  onPressed: () {},
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
