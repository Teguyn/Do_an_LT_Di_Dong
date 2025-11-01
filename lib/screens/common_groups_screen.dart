import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart'; // Import service
import 'group_detail_screen.dart'; // Import màn hình chat nhóm

class CommonGroupsScreen extends StatelessWidget {
  final String friendUid;
  final String friendName;

  const CommonGroupsScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    final UserService userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: Text("Nhóm chung với ${friendName}"),
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
         titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userService.getCommonGroupsStream(friendUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             debugPrint("Lỗi tải nhóm chung: ${snapshot.error}");
            return const Center(child: Text('Lỗi tải danh sách nhóm.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn không có nhóm chung nào.'));
          }

          final groupDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: groupDocs.length,
            itemBuilder: (context, index) {
              final doc = groupDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String groupName = data['groupName'] ?? 'Tên nhóm';
              final String? groupAvatarUrl = data['groupAvatarUrl'];
              final List<dynamic> memberUids = data['users'] ?? [];

              return ListTile(
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                 leading: CircleAvatar(
                   radius: 24,
                   backgroundImage: groupAvatarUrl != null ? NetworkImage(groupAvatarUrl) : null,
                   backgroundColor: Colors.grey.shade200,
                   child: groupAvatarUrl == null 
                      ? const Icon(Icons.group, size: 24, color: Colors.white) 
                      : null,
                 ),
                 title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.w500)),
                 subtitle: Text('${memberUids.length} thành viên'),
                 onTap: () {
                    // Mở màn hình chat nhóm
                    Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => GroupDetailScreen(
                           chatRoomId: doc.id,
                           groupName: groupName,
                         ),
                       ),
                    );
                 },
              );
            },
          );
        },
      ),
    );
  }
}
