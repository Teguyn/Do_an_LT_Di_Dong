import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import để dùng debugPrint
import 'dart:io'; // Import để dùng 'File'
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Collection lưu thông tin người dùng
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  // Collection lưu trạng thái bạn bè/lời mời
  final CollectionReference _friendshipsCollection =
      FirebaseFirestore.instance.collection('friendships');
  // Collection lưu các phòng chat (cả 1-1 và nhóm)
  final CollectionReference _chatRoomsCollection =
      FirebaseFirestore.instance.collection('chat_rooms');
  // Lấy thông tin người dùng hiện tại (nếu đã đăng nhập)
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- Các hàm Core (Lấy thông tin, Tìm kiếm User) ---

  // 1. Kiểm tra số điện thoại đã được đăng ký chưa
  Future<bool> checkUserExists(String phoneNumber) async {
    try {
      final querySnapshot =
          await _usersCollection.where('phone', isEqualTo: phoneNumber).limit(1).get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Lỗi kiểm tra user: $e");
      throw Exception("Lỗi khi kiểm tra số điện thoại: $e");
    }
  }

// 2. Lưu thông tin người dùng mới vào Firestore khi đăng ký thành công
Future<void> saveUserData({
  required String uid,
  required String name,
  required String phone,
}) async {
  try {
    await _usersCollection.doc(uid).set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'createdAt': Timestamp.now(),
      'name_lowercase': name.toLowerCase(), // Dùng để tìm kiếm
      'avatarUrl': null, // Ảnh đại diện (có thể cập nhật sau)
      'coverUrl': null,  // Ảnh bìa
      'bio': null,       // Tiểu sử cá nhân
      'isOnline': true,  // ✅ Trạng thái ban đầu khi đăng ký
      'lastSeen': FieldValue.serverTimestamp(), // ✅ Thời gian hoạt động cuối
    });
    debugPrint("✅ Lưu thông tin user $uid thành công.");
  } catch (e) {
    debugPrint("❌ Lỗi lưu User Data: $e");
    rethrow;
  }
}


  // 3. Lấy thông tin chi tiết của một người dùng dựa trên UID
  Future<DocumentSnapshot?> getUserData(String uid) async {
     try {
       final doc = await _usersCollection.doc(uid).get();
       return doc.exists ? doc : null;
     } catch(e) {
       debugPrint("Lỗi lấy User Data cho UID $uid: $e");
       return null;
     }
  }

  // 4. Tìm kiếm người dùng theo tên (tiền tố)
  Stream<QuerySnapshot> searchUsersByName(String query) {
    if (query.isEmpty) { return Stream.empty(); }
    String lowerCaseQuery = query.toLowerCase();
    return _usersCollection
        .orderBy('name_lowercase')
        .where('name_lowercase', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('name_lowercase', isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff')
        .limit(10)
        .snapshots();
  }

   // 5. Tìm kiếm người dùng theo SĐT (chính xác)
  Stream<QuerySnapshot> searchUsersByPhone(String query) {
     if (query.isEmpty) { return Stream.empty(); }
     String formattedPhone = query.trim();
     if (formattedPhone.startsWith('0')) {
         formattedPhone = '+84${formattedPhone.substring(1)}';
     } else if (RegExp(r'^[1-9]\d{8,9}$').hasMatch(formattedPhone)) {
        formattedPhone = '+84$formattedPhone';
     }
     
     if (formattedPhone.startsWith('+')) {
          return _usersCollection
             .where('phone', isEqualTo: formattedPhone)
             .limit(1)
             .snapshots();
     } else {
       return Stream.empty();
     }
  }

  // === CÁC HÀM QUẢN LÝ BẠN BÈ ===

  // 6. Kiểm tra trạng thái mối quan hệ
  Future<DocumentSnapshot?> getFriendshipStatus(String otherUserId) async {
    if (currentUser == null) {
        debugPrint("getFriendshipStatus: Lỗi - Người dùng chưa đăng nhập.");
        return null;
    }
    final String currentUserId = currentUser!.uid;
    List<String> userIds = [currentUserId, otherUserId]..sort();
    String docId = userIds.join('_');

    try {
       final doc = await _friendshipsCollection.doc(docId).get();
       return doc.exists ? doc : null;
     } catch (e) {
       debugPrint("Lỗi getFriendshipStatus ($docId): $e");
       return null; 
     }
  }

 // 7. Gửi lời mời kết bạn
  Future<void> sendFriendRequest(String receiverId) async {
    if (currentUser == null) throw Exception("Bạn cần đăng nhập để gửi lời mời.");
    final String senderId = currentUser!.uid;
    List<String> userIds = [senderId, receiverId]..sort();
    String docId = userIds.join('_');

    final senderDoc = await getUserData(senderId);
    final receiverDoc = await getUserData(receiverId);
    if (senderDoc == null || receiverDoc == null) throw Exception("Không tìm thấy thông tin người dùng.");

    final String senderName = (senderDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Người dùng';
    final String receiverName = (receiverDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Người dùng';
    final String? senderAvatar = (senderDoc.data() as Map<String, dynamic>?)?['avatarUrl'];
    final String? receiverAvatar = (receiverDoc.data() as Map<String, dynamic>?)?['avatarUrl'];

    try {
      final existingDoc = await _friendshipsCollection.doc(docId).get();
      if (existingDoc.exists) {
         final data = existingDoc.data() as Map<String, dynamic>? ?? {};
         final status = data['status'];
         if (status == 'pending') throw Exception("Lời mời đã được gửi trước đó.");
         if (status == 'accepted') throw Exception("Bạn và người này đã là bạn bè.");
      }

      await _friendshipsCollection.doc(docId).set({
        'users': userIds,
        'status': 'pending',
        'requesterId': senderId,
        'requestedAt': Timestamp.now(),
        'userNames': { senderId: senderName, receiverId: receiverName },
        'userAvatars': { senderId: senderAvatar, receiverId: receiverAvatar },
      });
      debugPrint("Đã gửi lời mời tới $receiverId");
    } catch (e) {
      debugPrint("Lỗi sendFriendRequest: $e");
      throw Exception(e is Exception ? e.toString().replaceFirst('Exception: ', '') : "Không thể gửi lời mời.");
    }
  }

  // 8. Chấp nhận lời mời kết bạn (và tạo phòng chat 1-1)
  Future<void> acceptFriendRequest(String friendshipDocId) async {
     if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
     final String currentUserId = currentUser!.uid;

     try {
        final doc = await _friendshipsCollection.doc(friendshipDocId).get();
         if (!doc.exists) throw Exception("Lời mời không tồn tại.");
         final data = doc.data() as Map<String, dynamic>;
         
         final String senderId = data['requesterId'];
         if (senderId == currentUserId) throw Exception("Bạn không thể tự chấp nhận lời mời của mình.");

         final Map<String, dynamic> userNames = data['userNames'] ?? {};
         final String senderName = userNames[senderId]?.toString() ?? 'Người dùng';
         final String receiverName = userNames[currentUserId]?.toString() ?? 'Bạn';

         WriteBatch batch = _firestore.batch();
         final friendshipRef = _friendshipsCollection.doc(friendshipDocId);
         batch.update(friendshipRef, {
            'status': 'accepted',
            'acceptedAt': Timestamp.now(),
         });

         // Tạo phòng chat 1-1 ngay khi chấp nhận
         String chatRoomId = _getChatRoomId(senderId, currentUserId);
         final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);

         batch.set(chatRoomRef, {
            'users': [senderId, currentUserId],
            'userNames': {
               senderId: senderName,
               currentUserId: receiverName
            },
            'userAvatars': data['userAvatars'] ?? {},
            'lastMessage': 'Các bạn đã là bạn bè. Hãy gửi lời chào!',
            'lastMessageTime': Timestamp.now(),
            'isGroup': false, // Đánh dấu đây là chat 1-1
         }, SetOptions(merge: true));

         await batch.commit();
         debugPrint("Đã chấp nhận lời mời và tạo phòng chat: $friendshipDocId");

     } catch (e) {
        debugPrint("Lỗi acceptFriendRequest: $e");
        throw Exception(e is Exception ? e.toString().replaceFirst('Exception: ', '') : "Không thể chấp nhận lời mời.");
     }
  }

   // 9. Xóa mối quan hệ (Từ chối, Hủy YC, Hủy Bạn)
   Future<void> removeFriendship(String friendshipDocId) async {
     if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
     try {
       final doc = await _friendshipsCollection.doc(friendshipDocId).get();
       if (!doc.exists) return;
       final users = (doc.data() as Map<String, dynamic>)['users'] as List<dynamic>? ?? [];
       if (!users.contains(currentUser!.uid)) {
          throw Exception("Không có quyền xóa mối quan hệ này.");
       }
       await _friendshipsCollection.doc(friendshipDocId).delete();
       debugPrint("Đã xóa mối quan hệ: $friendshipDocId");
     } catch (e) {
        debugPrint("Lỗi removeFriendship: $e");
        throw Exception(e is Exception ? e.toString().replaceFirst('Exception: ', '') : "Không thể thực hiện thao tác xóa.");
     }
   }

  // 10. Stream lấy danh sách Lời mời kết bạn (gửi đến mình)
  Stream<QuerySnapshot> getFriendRequestsStream() {
     if (currentUser == null) return Stream.empty();
     return _friendshipsCollection
         .where('users', arrayContains: currentUser!.uid)
         .where('status', isEqualTo: 'pending')
         .where('requesterId', isNotEqualTo: currentUser!.uid)
         .orderBy('requesterId') // Phải orderBy trường '!=' trước
         .orderBy('requestedAt', descending: true)
         .snapshots();
  }

  // 11. Stream lấy danh sách Bạn bè (đã chấp nhận)
   Stream<QuerySnapshot> getFriendsStream() {
      if (currentUser == null) return Stream.empty();
      return _friendshipsCollection
          .where('users', arrayContains: currentUser!.uid)
          .where('status', isEqualTo: 'accepted')
          .orderBy('acceptedAt', descending: true)
          .snapshots();
   }

   // --- Các hàm cho Profile (Chỉnh sửa cá nhân) ---

   // 12. Tải ảnh (Avatar/Cover Profile)
   Future<String> uploadImage(File imageFile, String storagePath) async {
     if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
     try {
       // Dùng path + UID làm tên file
       final ref = _storage.ref().child(storagePath).child(currentUser!.uid);
       UploadTask uploadTask = ref.putFile(imageFile);
       TaskSnapshot snapshot = await uploadTask;
       String downloadUrl = await snapshot.ref.getDownloadURL();
       return downloadUrl;
     } catch (e) {
       debugPrint("Lỗi tải ảnh lên Storage: $e");
       throw Exception("Tải ảnh thất bại.");
     }
   }
  
   // 13. Cập nhật dữ liệu người dùng (Tên, Bio, URL ảnh)
   Future<void> updateUserData(Map<String, dynamic> dataToUpdate) async {
     if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
     try {
        // Tự động cập nhật name_lowercase nếu name thay đổi
        if (dataToUpdate.containsKey('name')) {
           dataToUpdate['name_lowercase'] = dataToUpdate['name'].toLowerCase();
        }
        await _usersCollection.doc(currentUser!.uid).update(dataToUpdate);
        debugPrint("Cập nhật thông tin user thành công.");
     } catch (e) {
        debugPrint("Lỗi cập nhật User Data: $e");
        throw Exception("Cập nhật thông tin thất bại.");
     }
   }

   // 14. Helper tạo ID phòng chat 1-1
   String _getChatRoomId(String uid1, String uid2) {
     List<String> userIds = [uid1, uid2]..sort();
     return userIds.join('_');
   }

  // --- Các hàm cho Chat Nhóm ---

  // 15. Tải ảnh (Avatar nhóm)
  Future<String> uploadGroupImage(File imageFile, String groupId) async {
    try {
      final ref = _storage.ref().child('group_avatars').child(groupId);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Lỗi tải ảnh nhóm: $e");
      throw Exception("Tải ảnh thất bại.");
    }
  }

  // 16. Tạo phòng chat nhóm mới
  Future<void> createGroupChat({
    required String groupName,
    required File? groupAvatarFile,
    required List<String> memberUids, // Danh sách UID thành viên (KHÔNG bao gồm admin)
  }) async {
    if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
    final String adminUid = currentUser!.uid;
    if (!memberUids.contains(adminUid)) {
      memberUids.add(adminUid); // Thêm admin vào danh sách
    }
    
    Map<String, String> userNames = {};
    Map<String, String?> userAvatars = {};

    // Lấy thông tin của TẤT CẢ thành viên (bao gồm cả admin)
    for (String uid in memberUids) {
       final userDoc = await getUserData(uid);
       if (userDoc != null && userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          userNames[uid] = data['name'] ?? 'Người dùng';
          userAvatars[uid] = data['avatarUrl'];
       }
    }

    String? groupAvatarUrl;
    final groupDocRef = _chatRoomsCollection.doc(); // Tạo ID ngẫu nhiên
    
    if (groupAvatarFile != null) {
       groupAvatarUrl = await uploadGroupImage(groupAvatarFile, groupDocRef.id);
    }

    try {
      await groupDocRef.set({
        'isGroup': true, // Đánh dấu là nhóm
        'groupName': groupName,
        'groupAvatarUrl': groupAvatarUrl,
        'users': memberUids, // Danh sách UID tất cả thành viên
        'adminUids': [adminUid], // Người tạo là admin
        'createdAt': Timestamp.now(),
        'lastMessage': 'Đã tạo nhóm $groupName',
        'lastMessageTime': Timestamp.now(),
        'userNames': userNames,
        'userAvatars': userAvatars,
      });
      debugPrint("Đã tạo nhóm thành công: ${groupDocRef.id}");
    } catch (e) {
       debugPrint("Lỗi tạo nhóm: $e");
       throw Exception("Không thể tạo nhóm.");
    }
  }

  // 17. Stream lấy danh sách các nhóm mà user tham gia
  Stream<QuerySnapshot> getGroupsStream() {
     if (currentUser == null) return Stream.empty();
     return _chatRoomsCollection
         .where('isGroup', isEqualTo: true) // Chỉ lấy các phòng là nhóm
         .where('users', arrayContains: currentUser!.uid) // User hiện tại là thành viên
         .orderBy('lastMessageTime', descending: true) // Sắp xếp theo tin nhắn mới nhất
         .snapshots();
  }

  // 18. Stream lấy thông tin chi tiết CỦA MỘT nhóm
  Stream<DocumentSnapshot> getGroupStream(String chatRoomId) {
     return _chatRoomsCollection.doc(chatRoomId).snapshots();
  }

  // 19. Thêm thành viên vào nhóm (Chỉ Admin)
  Future<void> addMemberToGroup(String chatRoomId, String newMemberUid) async {
     // Lấy thông tin (tên, avatar) của newMemberUid
     final newMemberDoc = await getUserData(newMemberUid);
     if (newMemberDoc == null || !newMemberDoc.exists) throw Exception("Người dùng này không tồn tại.");
     
     final data = newMemberDoc.data() as Map<String, dynamic>;
     final newMemberName = data['name'] ?? 'Người dùng';
     final newMemberAvatar = data['avatarUrl'];

     try {
        // Cần kiểm tra quyền Admin ở Security Rules
        await _chatRoomsCollection.doc(chatRoomId).update({
           'users': FieldValue.arrayUnion([newMemberUid]),
           // Cập nhật map userNames và userAvatars
           'userNames.$newMemberUid': newMemberName,
           'userAvatars.$newMemberUid': newMemberAvatar,
        });
        debugPrint("Đã thêm $newMemberUid vào nhóm $chatRoomId");
     } catch (e) {
        debugPrint("Lỗi thêm thành viên: $e");
        throw Exception("Không thể thêm thành viên.");
     }
  }

  // 20. Rời nhóm
  Future<void> leaveGroup(String chatRoomId) async {
     if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
     final String uid = currentUser!.uid;
     try {
        await _chatRoomsCollection.doc(chatRoomId).update({
           'users': FieldValue.arrayRemove([uid]),
           'adminUids': FieldValue.arrayRemove([uid]), // Tự xóa admin nếu có
           // (Tùy chọn) Xóa tên và avatar khỏi map
           'userNames.$uid': FieldValue.delete(),
           'userAvatars.$uid': FieldValue.delete(),
        });
        debugPrint("User $uid đã rời nhóm $chatRoomId");
     } catch (e) {
        debugPrint("Lỗi rời nhóm: $e");
        throw Exception("Không thể rời nhóm.");
     }
   }

  // 21. Xóa thành viên (Chỉ Admin)
   Future<void> removeMemberFromGroup(String chatRoomId, String memberUid) async {
      if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
      // TODO: Cần kiểm tra quyền Admin (đã làm trong Rules, nhưng nên check cả ở đây)
      try {
         await _chatRoomsCollection.doc(chatRoomId).update({
           'users': FieldValue.arrayRemove([memberUid]),
           'adminUids': FieldValue.arrayRemove([memberUid]),
           'userNames.$memberUid': FieldValue.delete(),
           'userAvatars.$memberUid': FieldValue.delete(),
         });
         debugPrint("Đã xóa $memberUid khỏi nhóm $chatRoomId");
      } catch (e) {
         debugPrint("Lỗi xóa thành viên: $e");
         throw Exception("Không thể xóa thành viên.");
      }
   }
   // === CÁC HÀM MỚI CHO CHAT OPTIONS ===

   // 22. Lấy stream của 1 friendship doc
   // (Dùng để check Mute/Block)
   Stream<DocumentSnapshot> getFriendshipStream(String friendshipDocId) {
      return _friendshipsCollection.doc(friendshipDocId).snapshots();
   }

   // 23. Cập nhật data của friendship (cho Mute/Block)
   Future<void> updateFriendshipData(String friendshipDocId, Map<String, dynamic> data) async {
      try {
         await _friendshipsCollection.doc(friendshipDocId).update(data);
      } catch (e) {
         debugPrint("Lỗi cập nhật friendship: $e");
         throw Exception("Thao tác thất bại.");
      }
   }

   // 24. Lấy media (ảnh/video) từ 1 phòng chat
   Stream<QuerySnapshot> getSharedMediaStream(String chatRoomId) {
      return _chatRoomsCollection
         .doc(chatRoomId)
         .collection('messages')
         // TODO: Bạn cần thêm trường 'type' khi gửi tin nhắn
         // 'type': 'image' hoặc 'video'
         .where('type', whereIn: ['image', 'video'])
         .orderBy('createdAt', descending: true)
         .snapshots();
   }

   // 25. Lấy các nhóm chung với 1 người bạn
Stream<QuerySnapshot> getCommonGroupsStream(String friendUid) {
     if (currentUser == null) return Stream.empty();
     
     // SỬA: Chỉ query các nhóm CỦA BẠN (currentUser)
     // Việc lọc nhóm chung (có friendUid) sẽ được xử lý ở UI (CommonGroupsScreen)
     return _chatRoomsCollection
         .where('isGroup', isEqualTo: true)
         .where('users', arrayContains: currentUser!.uid) // Chỉ 1 lần arrayContains
         .snapshots();
   }
  // === HÀM TẢI ẢNH / VIDEO CHAT LÊN STORAGE ===
  Future<String> uploadChatMedia(String chatRoomId, File mediaFile, String mediaType) async {
    if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");

    try {
      final String fileName = '${Timestamp.now().millisecondsSinceEpoch}_${currentUser!.uid}';
      final String folderPath = 'chat_media/$chatRoomId/$mediaType';
      final ref = _storage.ref().child(folderPath).child(fileName);

      UploadTask uploadTask = ref.putFile(mediaFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("🔥 Lỗi upload media: $e");
      throw Exception("Không thể tải media lên Storage.");
    }
  }

    // === HÀM GỬI TIN NHẮN (văn bản hoặc ảnh) ===
  Future<void> sendMessage({
    required String chatRoomId,
    String? text,
    String? imageUrl,
  }) async {
    if (currentUser == null) return;

    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final messageRef = chatRoomRef.collection('messages').doc();

    final Timestamp now = Timestamp.now();

    // Lấy danh sách user trong phòng
    final chatDoc = await chatRoomRef.get();
    if (!chatDoc.exists) return;

    final data = chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> users = data['users'] ?? [];

    // Chuẩn bị batch để cập nhật đồng thời
    WriteBatch batch = _firestore.batch();

    // 1️⃣ Thêm tin nhắn mới
    batch.set(messageRef, {
      'senderId': currentUser!.uid,
      'text': text ?? '',
      'imageUrl': imageUrl ?? '',
      'createdAt': now,
      'isRevoked': false,
      'deletedFor': [],
    });

    // 2️⃣ Cập nhật thông tin phòng chat (lastMessage, unreadCounts)
    Map<String, dynamic> unreadUpdates = {};
    for (var uid in users) {
      if (uid == currentUser!.uid) {
        unreadUpdates['unreadCounts.$uid'] = 0;
      } else {
        // Tăng số tin chưa đọc của người khác
        unreadUpdates['unreadCounts.$uid'] =
            FieldValue.increment(1);
      }
    }

    batch.set(
      chatRoomRef,
      {
        'lastMessage': text != null && text.isNotEmpty
            ? text
            : (imageUrl != null ? '📷 Ảnh' : ''),
        'lastMessageTime': now,
        ...unreadUpdates,
      },
      SetOptions(merge: true),
    );

    // 3️⃣ Gửi batch commit
    await batch.commit();
  }
  // 26. Chỉ định hoặc hủy quyền Quản trị viên
Future<void> setAdminStatus(String chatRoomId, String memberUid, bool isAdmin) async {
  if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
  
  try {
    final chatDoc = await _chatRoomsCollection.doc(chatRoomId).get();
    if (!chatDoc.exists) throw Exception("Nhóm không tồn tại.");

    final List<dynamic> adminUids = (chatDoc.data() as Map<String, dynamic>)['adminUids'] ?? [];

    if (isAdmin) {
      // Thêm quyền Admin
      if (!adminUids.contains(memberUid)) {
        await _chatRoomsCollection.doc(chatRoomId).update({
          'adminUids': FieldValue.arrayUnion([memberUid]),
        });
      }
    } else {
      // Hủy quyền Admin
      if (adminUids.contains(memberUid)) {
        await _chatRoomsCollection.doc(chatRoomId).update({
          'adminUids': FieldValue.arrayRemove([memberUid]),
        });
      }
    }
    debugPrint("${isAdmin ? 'Đã chỉ định' : 'Đã hủy'} quyền quản trị viên cho $memberUid trong nhóm $chatRoomId");
  } catch (e) {
    debugPrint("Lỗi setAdminStatus: $e");
    throw Exception("Không thể cập nhật quyền quản trị viên.");
  }
}

// 27. Xóa thành viên khỏi nhóm (Chỉ Admin có quyền)
// Nếu chưa có hàm này, bạn có thể dùng luôn hàm removeMemberFromGroup đã có
// Nhưng nếu muốn tách riêng rõ ràng, thêm kiểm tra quyền Admin tại đây
Future<void> removeMemberFromGroupWithAdminCheck(String chatRoomId, String memberUid) async {
  if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");
  try {
    final chatDoc = await _chatRoomsCollection.doc(chatRoomId).get();
    if (!chatDoc.exists) throw Exception("Nhóm không tồn tại.");

    final data = chatDoc.data() as Map<String, dynamic>;
    final List<dynamic> adminUids = data['adminUids'] ?? [];
    final String currentUid = currentUser!.uid;

    if (!adminUids.contains(currentUid)) {
      throw Exception("Bạn không có quyền xóa thành viên. Chỉ Admin mới được phép.");
    }

    if (memberUid == currentUid) {
      throw Exception("Không thể xóa chính bạn. Nếu muốn rời nhóm, hãy dùng chức năng rời nhóm.");
    }

    await _chatRoomsCollection.doc(chatRoomId).update({
      'users': FieldValue.arrayRemove([memberUid]),
      'adminUids': FieldValue.arrayRemove([memberUid]),
      'userNames.$memberUid': FieldValue.delete(),
      'userAvatars.$memberUid': FieldValue.delete(),
    });

    debugPrint("Đã xóa $memberUid khỏi nhóm $chatRoomId");
  } catch (e) {
    debugPrint("Lỗi removeMemberFromGroupWithAdminCheck: $e");
    throw Exception(e is Exception ? e.toString().replaceFirst('Exception: ', '') : "Không thể xóa thành viên.");
  }
}

// 28. Cập nhật trạng thái (Online/Offline) của user hiện tại
  Future<void> updateUserPresence(String status) async {
    if (currentUser == null) return;
    try {
      await _usersCollection.doc(currentUser!.uid).update({
        'status': status,
        'lastSeen': Timestamp.now(), // Luôn cập nhật thời gian
      });
      debugPrint("Cập nhật trạng thái: $status");
    } catch (e) {
      // Bỏ qua lỗi (ví dụ: lỗi mạng khi app đang đóng)
      debugPrint("Lỗi cập nhật trạng thái: $e");
    }
  }

  // 29. Lấy Stream thông tin của 1 user (để xem trạng thái)
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _usersCollection.doc(uid).snapshots();
  }
  
} // End of UserService

