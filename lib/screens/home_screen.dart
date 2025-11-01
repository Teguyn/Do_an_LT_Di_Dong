import 'package:flutter/material.dart';
// Đảm bảo import đúng đường dẫn đến các màn hình khác
import 'chat_list_screen.dart'; // Màn hình danh sách chat
// Giả định bạn đã tạo các file này (có thể là placeholder)
import 'group_chat_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';    // Màn hình quản lý bạn bè

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // State và Controller cho thanh tìm kiếm
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Danh sách các Widget tương ứng với các tab
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Khởi tạo danh sách trang ban đầu
    _updatePages();
    // Lắng nghe sự thay đổi trong ô tìm kiếm
    _searchController.addListener(_onSearchChanged);
  }

  // Hàm cập nhật danh sách trang (quan trọng khi searchQuery thay đổi)
  void _updatePages() {
     _pages = [
      // Trang 0: Truyền searchQuery vào ChatListScreen
      ChatListScreen(searchQuery: _searchQuery),
      // Thay thế các Center bằng Widget thật cho các màn hình còn lại
      // Ví dụ nếu bạn đã tạo các screen khác:
      GroupChatScreen(),
      PostScreen(),
      ProfileScreen(),
    ];
  }

  // Hàm được gọi khi nội dung ô tìm kiếm thay đổi
  void _onSearchChanged() {
    // Chỉ cập nhật và rebuild nếu đang ở tab Chat (index 0)
    // và widget vẫn còn tồn tại (mounted)
    if (mounted && _selectedIndex == 0) {
       setState(() {
        _searchQuery = _searchController.text;
        // Cập nhật lại widget ChatListScreen trong danh sách _pages
        // để nó nhận searchQuery mới và lọc lại danh sách
        _pages[0] = ChatListScreen(searchQuery: _searchQuery);
      });
    }
  }

  @override
  void dispose() {
    // Hủy lắng nghe và dispose controller khi widget bị hủy
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Không hiển thị nút back
        titleSpacing: 16.0, // Khoảng cách tiêu đề
        elevation: 0, // Bỏ shadow dưới AppBar
        // Nền Gradient cho AppBar
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Màu gradient tím-xanh
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Title: Hiển thị thanh tìm kiếm hoặc tên Tab
        title: _selectedIndex == 0
            // Nếu là Tab Chat (index 0) -> Hiển thị TextField
            ? TextField(
                controller: _searchController,
                // onChanged đã được xử lý bởi listener ở initState
                decoration: InputDecoration(
                  hintText: "Tìm kiếm cuộc trò chuyện...", // Nội dung gợi ý
                  hintStyle: const TextStyle(color: Colors.white70), // Màu chữ gợi ý
                  border: InputBorder.none, // Bỏ đường viền
                  prefixIcon: const Icon(Icons.search, color: Colors.white), // Icon tìm kiếm
                   // Nút 'x' để xóa nội dung tìm kiếm
                   suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          // Icon xóa
                          icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
                          onPressed: () {
                             _searchController.clear(); // Xóa text trong controller
                             // Listener _onSearchChanged sẽ tự động cập nhật UI
                          },
                          constraints: const BoxConstraints(), // Xóa padding mặc định IconButton
                          padding: const EdgeInsets.only(right: 12), // Padding bên phải nút xóa
                        )
                      : null, // Không hiển thị nút xóa nếu ô tìm kiếm rỗng
                   contentPadding: const EdgeInsets.symmetric(vertical: 15), // Căn dọc nội dung TextField
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16), // Màu chữ khi gõ
                cursorColor: Colors.white, // Màu con trỏ
              )
            // Nếu là các Tab khác -> Hiển thị tên Tab
            : Text(
                _selectedIndex == 1 ? "Nhóm" : _selectedIndex == 2 ? "Tin" : "Cá nhân",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20), // Style tên Tab
              ),

        // Actions: Các nút bên phải AppBar
        actions: [
          // Nút điều hướng đến màn hình Bạn bè
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white), // Icon thêm bạn bè
            tooltip: 'Bạn bè', // Chú thích khi giữ chuột
            onPressed: () {
              // Mở màn hình FriendsScreen
              Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
          ),
          const SizedBox(width: 8), // Khoảng cách nhỏ cuối AppBar
        ],
      ),
      // Body: Hiển thị trang tương ứng với Tab đang chọn
      body: IndexedStack( // Dùng IndexedStack để giữ trạng thái của các trang khi chuyển tab
        index: _selectedIndex,
        children: _pages, // Danh sách các widget màn hình
      ),
      // BottomNavigationBar: Thanh điều hướng dưới cùng
      bottomNavigationBar: Container(
        // Style cho thanh BottomNav (bo góc, đổ bóng)
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Bo góc trên
          color: Colors.white, // Nền trắng
          boxShadow: [ // Đổ bóng nhẹ lên trên
            BoxShadow( color: Colors.grey.withAlpha(51), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, -1)) // ~20% alpha grey
          ],
        ),
        child: ClipRRect( // Clip để áp dụng bo góc cho BottomNavigationBar bên trong
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed, // Luôn hiển thị label của các mục
            currentIndex: _selectedIndex, // Mục đang được chọn
            selectedItemColor: const Color(0xFF6A11CB), // Màu icon và label khi được chọn
            unselectedItemColor: Colors.grey.shade500, // Màu icon và label khi không được chọn
            backgroundColor: Colors.transparent, // Nền trong suốt (để màu của Container hiển thị)
            elevation: 0, // Bỏ shadow mặc định
            selectedFontSize: 12, // Cỡ chữ label khi chọn
            unselectedFontSize: 12, // Cỡ chữ label khi không chọn
            // Hàm xử lý khi nhấn vào một mục
            onTap: (index) {
                // Chỉ cập nhật state nếu chọn mục khác mục hiện tại
                if (_selectedIndex != index) {
                   setState(() => _selectedIndex = index); // Cập nhật index đang chọn
                   // Nếu chuyển sang tab khác KHÔNG PHẢI tab Chat (index 0)
                   // VÀ thanh tìm kiếm đang có nội dung
                   if (index != 0 && _searchController.text.isNotEmpty) {
                       // Tự động xóa nội dung thanh tìm kiếm
                       _searchController.clear();
                       // Listener _onSearchChanged sẽ tự động cập nhật _searchQuery và _pages[0]
                   }
                }
            },
            // Danh sách các mục trên BottomNav
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline), // Icon thường
                  activeIcon: Icon(Icons.chat_bubble),   // Icon khi được chọn
                  label: "Tin Nhắn"),                       // Label
              BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  activeIcon: Icon(Icons.group),
                  label: "Nhóm"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.article_outlined),
                  activeIcon: Icon(Icons.article),
                   label: "Tin"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                   label: "Cá nhân"),
            ],
          ),
        ),
      ),
    );
  }
}

