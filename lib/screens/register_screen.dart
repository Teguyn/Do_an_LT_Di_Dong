import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // <-- Không cần nữa
import '/services/auth_service.dart'; // <-- THAY THẾ
import '/services/user_service.dart'; // <-- THÊM Service User
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
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

  // === HÀM _registerUser ĐÃ ĐƯỢC LÀM GỌN ===
  Future<void> _registerUser() async {
    final String name = nameController.text.trim();
    final String phone = phoneController.text.trim();

    if (phone.isEmpty || name.isEmpty) {
      _showError("Vui lòng nhập đầy đủ Tên và Số điện thoại");
      return;
    }
    setState(() { _isLoading = true; });

    // Định dạng SĐT
    String phoneNumber = phone;
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '+84${phoneNumber.substring(1)}';
    } else if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+84$phoneNumber';
    }

    try {
      // 2. Gọi UserService để kiểm tra SĐT tồn tại
      bool userExists = await _userService.checkUserExists(phoneNumber);

      // 3. Nếu đã tồn tại -> Báo lỗi <<<---- LỖI BẠN GẶP LÀ Ở ĐÂY
      if (userExists) {
        _showError("Số điện thoại này đã được đăng ký."); // <-- Thông báo này
        setState(() { _isLoading = false; });
        return; // Dừng lại
      }

      // 4. Nếu CHƯA tồn tại -> Gọi AuthService để gửi OTP
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
                phoneNumber: receivedPhoneNumber,
                name: name, // <-- Truyền tên sang OTP
              ),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() { _isLoading = false; });
          _showError(error);
        },
        onVerificationComplete: () {
           if (!mounted) return;
           setState(() { _isLoading = false; });
           debugPrint("Xác thực tự động thành công!");
        },
        onCodeTimeout: (verificationId) {
            debugPrint("OTP timeout cho verificationId: $verificationId");
        },
      );

    } catch (e) {
      setState(() { _isLoading = false; });
       debugPrint("Lỗi chi tiết khi đăng ký: ${e.toString()}");
      _showError("Đã xảy ra lỗi khi kiểm tra SĐT: $e");
    }
  }

 @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

 // UI giữ nguyên
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
                const Icon(Icons.person_add, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Đăng ký tài khoản",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                // Họ tên
                _buildInputField(
                  controller: nameController,
                  icon: Icons.person,
                  hintText: "Họ và tên",
                ),
                const SizedBox(height: 16),
                // Số điện thoại
                _buildInputField(
                  controller: phoneController,
                  icon: Icons.phone,
                  hintText: "Số điện thoại",
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 30),
                // Nút đăng ký
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _registerUser, // Gọi hàm đăng ký
                        child: const Text("Đăng ký",
                            style: TextStyle(fontSize: 18)),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Đảm bảo nút này quay về LoginScreen
                    if (Navigator.canPop(context)) {
                       Navigator.pop(context);
                    } else {
                       // Nếu không thể pop, đi đến login (phòng trường hợp)
                       Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  child: const Text(
                    "Đã có tài khoản? Đăng nhập",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (Hàm _buildInputField của bạn giữ nguyên)
  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // ... (code giữ nguyên)
// aikaneko:ignore
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon),
          hintText: hintText,
        ),
      ),
    );
// aikaneko:ignore
  }
}

