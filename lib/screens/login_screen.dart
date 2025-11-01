import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // <-- Không cần nữa
// import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Không cần nữa
import '/services/auth_service.dart'; // <-- THAY THẾ
import '/services/user_service.dart'; // <-- THÊM Service User
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;

  // 1. Khởi tạo AuthService và UserService
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // === HÀM _loginUser ĐÃ ĐƯỢC LÀM GỌN ===
  Future<void> _loginUser() async {
    if (phoneController.text.isEmpty) {
      _showError("Vui lòng nhập số điện thoại");
      return;
    }
    setState(() { _isLoading = true; });

    // Định dạng SĐT
    String phoneNumber = phoneController.text.trim();
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '+84${phoneNumber.substring(1)}';
    } else if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+84$phoneNumber';
    }

    try {
      // 2. Gọi UserService để kiểm tra SĐT tồn tại
      bool userExists = await _userService.checkUserExists(phoneNumber);

      // 3. Nếu không tồn tại -> Báo lỗi
      if (!userExists) {
        _showError("Số điện thoại này chưa được đăng ký.");
        setState(() { _isLoading = false; });
        return;
      }

      // 4. Nếu tồn tại -> Gọi AuthService để gửi OTP
      await _authService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, receivedPhoneNumber) {
          if (!mounted) return;
          setState(() { _isLoading = false; });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                verificationId: verificationId,
                phoneNumber: receivedPhoneNumber, // Dùng SĐT đã được format
                name: null, // null cho luồng đăng nhập
              ),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() { _isLoading = false; });
          _showError(error); // Hiển thị lỗi từ AuthService
        },
        onVerificationComplete: () {
           if (!mounted) return;
           setState(() { _isLoading = false; });
           print("Xác thực tự động thành công!");
           // Bạn có thể xử lý đăng nhập tự động ở đây nếu muốn
           // Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        },
         onCodeTimeout: (verificationId) {
            // Có thể hiển thị thông báo timeout nếu cần
             // Sử dụng debugPrint thay vì print cho production code tốt hơn
            debugPrint("OTP timeout cho verificationId: $verificationId");
         },
      );

    } catch (e) {
      // Xử lý lỗi từ checkUserExists hoặc lỗi chung khác
      setState(() { _isLoading = false; });
       // === ĐẢM BẢO DÒNG NÀY CÓ ĐỂ XEM LỖI CHI TIẾT ===
      debugPrint("Lỗi chi tiết khi kiểm tra SĐT: ${e.toString()}");
      // ============================================
      _showError("Đã xảy ra lỗi khi kiểm tra SĐT."); // Thông báo chung cho user
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // === UI GIỮ NGUYÊN ===
  @override
  Widget build(BuildContext context) {
     return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.purple.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "MyChat",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),
                // Ô nhập số điện thoại
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Nhập số điện thoại",
                      icon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(height: 20),
                // Nút đăng nhập
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _loginUser, // Gọi hàm đã sửa
                        child: const Text("Đăng nhập",
                            style: TextStyle(fontSize: 18)),
                      ),
                const SizedBox(height: 20),
                // Hàng chứa nút Đăng ký
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        "Chưa có tài khoản? Đăng ký",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

