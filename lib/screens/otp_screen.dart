import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
// Đảm bảo import đúng UserService
import '../services/user_service.dart'; // Giả sử UserService ở lib/services/

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String? name; // name != null khi là luồng đăng ký

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.name,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  // Khởi tạo UserService để gọi hàm lưu
  final UserService _userService = UserService();
  final AuthService _authService = AuthService(); // Khởi tạo AuthService để gọi verify

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _verifyOTP() async {
    if (otpController.text.trim().isEmpty || otpController.text.trim().length != 6) {
       _showError('Vui lòng nhập mã OTP gồm 6 chữ số.');
       return;
    }
    setState(() { _isLoading = true; });

    try {
      debugPrint("Bắt đầu xác thực OTP..."); // DEBUG

      // Gọi hàm xác thực từ AuthService
      final userCredential = await _authService.verifyOtpAndSignIn(
        verificationId: widget.verificationId,
        smsCode: otpController.text.trim(),
      );

      // Kiểm tra userCredential có tồn tại không
      if (userCredential?.user != null) {
        debugPrint("Xác thực OTP thành công! User UID: ${userCredential!.user!.uid}"); // DEBUG

        // === Logic Lưu Dữ liệu khi Đăng ký ===
        if (widget.name != null) { // Chỉ thực hiện khi đến từ RegisterScreen
          debugPrint("Đây là luồng Đăng ký (có widget.name). Bắt đầu lưu dữ liệu..."); // DEBUG
          try {
            await _userService.saveUserData(
              uid: userCredential.user!.uid,
              name: widget.name!,
              phone: widget.phoneNumber,
            );
            debugPrint("Lưu dữ liệu vào Firestore thành công!"); // DEBUG

            // Đăng xuất để buộc người dùng đăng nhập lại
            await _authService.signOut();
            debugPrint("Đã đăng xuất sau khi đăng ký."); // DEBUG

            // Điều hướng về trang Login với thông báo thành công
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              // Hiển thị SnackBar sau khi đã chuyển trang (cần GlobalKey hoặc cách khác)
              // Tạm thời chỉ in ra console
              debugPrint("Đăng ký thành công! Vui lòng đăng nhập.");
              // Hoặc hiển thị SnackBar ngay trước khi chuyển trang (có thể bị giật)
              // _showSuccess("Đăng ký thành công! Vui lòng đăng nhập.");
            }
          } catch (saveError) {
             debugPrint("!!! LỖI khi lưu dữ liệu Firestore: ${saveError.toString()}"); // DEBUG LỖI LƯU
             _showError("Đăng ký thành công nhưng không thể lưu thông tin người dùng.");
             // Vẫn đăng xuất và về trang login để tránh user bị đăng nhập mà chưa có data
              await _authService.signOut();
              if (mounted) {
                 Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
          }
        }
        // === Logic Điều hướng khi Đăng nhập ===
        else {
          debugPrint("Đây là luồng Đăng nhập (widget.name là null). Điều hướng tới /home..."); // DEBUG
          // Điều hướng đến trang chủ
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          }
        }
      } else {
         // Trường hợp hiếm khi verifyOtpAndSignIn trả về null
         debugPrint("!!! LỖI: verifyOtpAndSignIn trả về null."); // DEBUG
         _showError('Xác thực thành công nhưng không lấy được thông tin người dùng.');
      }

    } on FirebaseAuthException catch (e) {
      debugPrint("!!! LỖI FirebaseAuthException khi xác thực OTP: ${e.code} - ${e.message}"); // DEBUG LỖI AUTH
      if (e.code == 'invalid-verification-code') {
        _showError('Mã OTP không hợp lệ.');
      } else {
        _showError('Lỗi xác thực: ${e.message}');
      }
    } catch (e) {
      debugPrint("!!! LỖI không xác định khi xác thực OTP: ${e.toString()}"); // DEBUG LỖI KHÁC
      _showError('Đã xảy ra lỗi không xác định. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // Hàm hiển thị thông báo thành công (ví dụ)
  // void _showSuccess(String message) {
  //    if (!mounted) return;
  //    ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(message), backgroundColor: Colors.green),
  //    );
  // }


  @override
  void dispose() {
     otpController.dispose();
     super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (Phần UI của OTPScreen giữ nguyên) ...
// aikaneko:ignore
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
                const Icon(Icons.sms, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Xác thực OTP",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  "Mã OTP đã được gửi đến SĐT:\n${widget.phoneNumber}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Ô nhập OTP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: otpController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Nhập mã OTP (6 số)",
                      icon: Icon(Icons.password),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6, // Giới hạn 6 ký tự
                     style: const TextStyle(letterSpacing: 8, fontSize: 18), // Tăng khoảng cách chữ
                     onChanged: (value) { // Tự động submit khi đủ 6 số
                       if (value.length == 6) {
                         _verifyOTP();
                       }
                     },
                  ),
                ),
                const SizedBox(height: 20),
                // Nút xác nhận
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
                        onPressed: _verifyOTP, // Gọi hàm xác thực
                        child:
                            const Text("Xác nhận", style: TextStyle(fontSize: 18)),
                      ),
                const SizedBox(height: 20),
                 // (Tùy chọn) Nút gửi lại OTP
                 TextButton(
                    onPressed: () {
                       // TODO: Thêm logic gửi lại OTP (gọi lại verifyPhoneNumber với resendToken nếu có)
                       _showError("Chức năng gửi lại OTP chưa được thực hiện.");
                    },
                    child: const Text(
                       'Chưa nhận được mã? Gửi lại',
                       style: TextStyle(color: Colors.white70),
                    ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
// aikaneko:ignore
  }
}

