import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart'
    show AuthService, UserProfile, UserProfileProvider;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  static const int totalSteps = 6;
  int currentStep = 1;
  bool _isSubmitting = false;
  final String _apiUrl = dotenv.env['API_URL'] ??
      (throw Exception('API_URL not found in .env file'));
  String get _saveProfileEndpoint => '$_apiUrl/profile';

  // 입력값 상태
  DateTime? birthDate;
  double? height;
  double? weight;
  String? gender; // 'male' or 'female'
  String? activityLevel; // 'sedentary', 'light', 'moderate', 'very', 'extra'
  String? goal; // 'maintain', 'gain', 'lose'

  // 입력 컨트롤러
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (currentStep < totalSteps) {
      setState(() {
        currentStep++;
      });
    } else {
      _submitProfile();
    }
  }

  void _prevStep() {
    if (currentStep > 1) {
      setState(() {
        currentStep--;
      });
    }
  }

  Future<void> _submitProfile() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Validate required fields
      if (birthDate == null ||
          height == null ||
          weight == null ||
          gender == null ||
          activityLevel == null ||
          goal == null) {
        throw 'Please fill in all required fields';
      }

      // Get access token
      final token = await AuthService.instance.getAccessToken();
      if (token == null) {
        throw 'Authentication token not found. Please log in again.';
      }

      // Prepare request body
      final body = {
        'birthdate':
            '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
        'height': height,
        'weight': weight,
        'gender': gender,
        'activity_level': activityLevel,
        'goal': goal,
      };

      // Make PATCH request
      final response = await http.patch(
        Uri.parse(_saveProfileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - fetch profile and update provider, then navigate
        try {
          final profileJson = await AuthService.instance.fetchUserProfile();
          final userProfile = UserProfile.fromJson(profileJson);
          if (mounted) {
            context.read<UserProfileProvider>().setProfile(userProfile);
            if (userProfile.birthdate.isEmpty || userProfile.gender.isEmpty) {
              Navigator.pushReplacementNamed(context, '/onboarding');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        } catch (e) {
          // Optionally handle profile fetch error
        }
      } else {
        // Handle error response
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ??
            'Failed to save profile. Please try again.';
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 1:
        return _buildBirthDateStep();
      case 2:
        return _buildHeightStep();
      case 3:
        return _buildWeightStep();
      case 4:
        return _buildGenderStep();
      case 5:
        return _buildActivityStep();
      case 6:
        return _buildGoalStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBirthDateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter your date of birth',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: birthDate ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      birthDate = picked;
                    });
                  }
                },
                child: Text(
                  birthDate == null
                      ? 'Select date'
                      : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeightStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter your height (cm)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(
          controller: heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 170'),
          onChanged: (v) => height = double.tryParse(v),
        ),
      ],
    );
  }

  Widget _buildWeightStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter your weight (kg)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(
          controller: weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 65'),
          onChanged: (v) => weight = double.tryParse(v),
        ),
      ],
    );
  }

  Widget _buildGenderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select your gender',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Male'),
                value: 'male',
                groupValue: gender,
                onChanged: (v) => setState(() => gender = v),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Female'),
                value: 'female',
                groupValue: gender,
                onChanged: (v) => setState(() => gender = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select your activity level',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        RadioListTile<String>(
          title: const Text('Sedentary'),
          subtitle: const Text('little to no exercise, desk job'),
          value: 'sedentary',
          groupValue: activityLevel,
          onChanged: (v) => setState(() => activityLevel = v),
        ),
        RadioListTile<String>(
          title: const Text('Lightly Active'),
          subtitle: const Text('exercise 1 to 3 days per week'),
          value: 'light',
          groupValue: activityLevel,
          onChanged: (v) => setState(() => activityLevel = v),
        ),
        RadioListTile<String>(
          title: const Text('Moderately Active'),
          subtitle: const Text('exercise 3 to 5 days per week'),
          value: 'moderate',
          groupValue: activityLevel,
          onChanged: (v) => setState(() => activityLevel = v),
        ),
        RadioListTile<String>(
          title: const Text('Very Active'),
          subtitle: const Text('exercise 6 to 7 days per week'),
          value: 'very',
          groupValue: activityLevel,
          onChanged: (v) => setState(() => activityLevel = v),
        ),
        RadioListTile<String>(
          title: const Text('Extra Active'),
          subtitle: const Text('exercise 2x per day'),
          value: 'extra',
          groupValue: activityLevel,
          onChanged: (v) => setState(() => activityLevel = v),
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select your goal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        RadioListTile<String>(
          title: const Text('Maintain weight'),
          value: 'maintain',
          groupValue: goal,
          onChanged: (v) => setState(() => goal = v),
        ),
        RadioListTile<String>(
          title: const Text('Gain weight'),
          value: 'gain',
          groupValue: goal,
          onChanged: (v) => setState(() => goal = v),
        ),
        RadioListTile<String>(
          title: const Text('Lose weight'),
          value: 'lose',
          groupValue: goal,
          onChanged: (v) => setState(() => goal = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Profile Setup',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: currentStep / totalSteps,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF006FFD)),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('$currentStep / $totalSteps',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildStepContent()),
              Row(
                children: [
                  if (currentStep > 1)
                    OutlinedButton(
                      onPressed: _prevStep,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006FFD),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(currentStep == totalSteps ? 'Finish' : 'Next',
                            style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
