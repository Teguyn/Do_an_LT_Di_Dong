import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Hàm gửi OTP (Dùng cho cả Đăng nhập và Đăng ký)
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, String phoneNumber) onCodeSent,
    required Function(String error) onError,
    required Function() onVerificationComplete,
    required Function(String verificationId) onCodeTimeout, // Thêm timeout callback
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          onVerificationComplete();
        },
        verificationFailed: (FirebaseAuthException e) {
          onError('Lỗi gửi mã OTP: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, phoneNumber);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
           onCodeTimeout(verificationId); // Gọi callback khi timeout
        },
      );
    } catch (e) {
      onError("Đã xảy ra lỗi khi gửi OTP: $e");
    }
  }

  // 2. Hàm xác thực OTP và đăng nhập
  Future<UserCredential?> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      // Ném lỗi ra ngoài để UI xử lý
      rethrow;
    }
  }

  // 3. Hàm đăng xuất (Có thể thêm vào đây)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 4. Lấy người dùng hiện tại (Có thể thêm)
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // 5. Stream trạng thái đăng nhập (Có thể thêm)
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}

