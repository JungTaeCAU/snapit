import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  AuthService._internal();

  CognitoUserPool? _userPool;
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';

  // Reset the singleton instance
  static void reset() {
    _instance = null;
  }

  void init() {
    // Always create a new user pool instance
    _userPool = CognitoUserPool(
      'us-east-1_fQDd3bTqc',
      'jqcqu82cdnp3mbv8i1om3hg1f',
    );
  }

  Future<CognitoUserSession?> signIn(String email, String password) async {
    try {
      // Always ensure user pool is initialized
      init();

      final cognitoUser = CognitoUser(
        email,
        _userPool!,
      );

      final authDetails = AuthenticationDetails(
        username: email,
        password: password,
      );

      final session = await cognitoUser.authenticateUser(authDetails);

      // Save login state to local storage for auto-login
      await _saveLoginState(email);

      return session;
    } catch (e) {
      print('Original error: $e');
      if (e.toString().contains('NotAuthorizedException')) {
        throw 'Incorrect email or password';
      } else if (e.toString().contains('UserNotFoundException')) {
        throw 'User not found';
      } else if (e.toString().contains('ResourceNotFoundException')) {
        throw 'Authentication service is not available. Please try again.';
      } else {
        rethrow;
      }
    }
  }

  // Save login state to local storage
  Future<void> _saveLoginState(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
  }

  // Check if user is logged in from local storage
  Future<bool> isLoggedInLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Get stored user email
  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Clear local login state
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
  }

  // Public method to clear login state
  Future<void> clearLoginState() async {
    await _clearLoginState();
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    try {
      // Always ensure user pool is initialized
      init();

      final userAttributes = [
        AttributeArg(
          name: 'email',
          value: email,
        ),
      ];

      final result = await _userPool!.signUp(
        email,
        password,
        userAttributes: userAttributes,
      );

      return {
        'statusCode': 200,
        'userSub': result.userSub,
        'message': 'Sign up successful! Please verify your email.',
      };
    } catch (e) {
      if (e.toString().contains('UsernameExistsException')) {
        throw 'An account with this email already exists.';
      } else if (e.toString().contains('InvalidPasswordException')) {
        throw 'Password must be at least 8 characters long and contain uppercase, lowercase, numbers, and special characters.';
      } else {
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    try {
      // Always ensure user pool is initialized
      init();

      final cognitoUser = await _userPool!.getCurrentUser();
      if (cognitoUser != null) {
        await cognitoUser.signOut();
      }

      // Clear local login state
      await _clearLoginState();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      // Always ensure user pool is initialized
      init();

      final cognitoUser = await _userPool!.getCurrentUser();
      if (cognitoUser == null) return false;

      final session = await cognitoUser.getSession();
      return session?.isValid() ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> confirmSignUp(String email, String code) async {
    try {
      init();
      final cognitoUser = CognitoUser(email, _userPool!);
      final result = await cognitoUser.confirmRegistration(code);
      if (result != true) {
        throw '인증에 실패했습니다. 코드를 다시 확인해주세요.';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> resendCode(String email) async {
    try {
      init();
      final cognitoUser = CognitoUser(email, _userPool!);
      await cognitoUser.resendConfirmationCode();
    } catch (e) {
      throw e.toString();
    }
  }

  // 현재 사용자의 액세스 토큰 가져오기
  Future<String?> getAccessToken() async {
    try {
      init();
      final cognitoUser = await _userPool!.getCurrentUser();
      if (cognitoUser == null) return null;

      final session = await cognitoUser.getSession();
      if (session?.isValid() == true) {
        return session!.getAccessToken().getJwtToken();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
