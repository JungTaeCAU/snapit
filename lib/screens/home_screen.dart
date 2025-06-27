import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/food_candidate.dart';
import '../models/meal_event.dart';
import '../services/image_upload_service.dart';
import '../widgets/add_meal_bottom_sheet.dart';
import '../widgets/image_picker_dialog.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../services/food_log_service.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImageUploadService _uploadService = ImageUploadService();
  bool _isUploading = false;
  XFile? _selectedImage;
  final List<MealEvent> _mealEvents = [];
  List<MealEvent> _foodLogs = [];
  bool _isLoading = true;
  String? _error;
  DateTime _currentDay = DateTime.now();
  int _listKey = 0; // AnimatedSwitcher용
  String _currentMonthKey = '';

  @override
  void initState() {
    super.initState();
    _currentMonthKey = _monthKey(_currentDay.year, _currentDay.month);
    _loadFoodLogsForDay(_currentDay);
  }

  String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _loadFoodLogsForDay(DateTime day) async {
    final newMonthKey = _monthKey(day.year, day.month);
    final monthCache = FoodLogService.instance.monthCache;
    if (newMonthKey == _currentMonthKey &&
        monthCache.containsKey(newMonthKey)) {
      // 같은 월 내에서는 캐시에서 바로 필터링
      setState(() {
        _foodLogs = monthCache[newMonthKey]!
            .where((log) =>
                log.timestamp.year == day.year &&
                log.timestamp.month == day.month &&
                log.timestamp.day == day.day)
            .toList();
        _isLoading = false;
        _listKey++;
      });
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final logs = await FoodLogService.instance.getFoodLogsForDay(day);
      _currentMonthKey = newMonthKey;

      setState(() {
        _foodLogs = logs;
        _isLoading = false;
        _listKey++;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _changeDay(int offset) {
    setState(() {
      _currentDay = _currentDay.add(Duration(days: offset));
    });
    _loadFoodLogsForDay(_currentDay);
  }

  String _getSimpleDate(DateTime date) {
    return DateFormat('MMMM, d').format(date);
  }

  void _resetImageSelection() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _onCameraPressed() async {
    try {
      final XFile? imageFile =
          await ImagePickerHelper.showImagePickerDialog(context);
      if (imageFile != null) {
        setState(() {
          _selectedImage = imageFile;
        });
        _showUploadDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                      : Image.file(File(_selectedImage!.path),
                          fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Do you want to upload this photo?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetImageSelection();
            },
            child: const Text('Cancel'),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006FFD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isUploading = true;
    });

    try {
      final Map<String, dynamic>? uploadResult =
          await _uploadService.uploadImage(_selectedImage!);
      if (mounted) {
        Navigator.of(context).pop(); // Close upload dialog
        if (uploadResult != null &&
            uploadResult['candidates'] != null &&
            uploadResult['candidates'].isNotEmpty) {
          final candidates = uploadResult['candidates'] as List<FoodCandidate>;
          final objectKey = uploadResult['objectKey'] as String;
          _showAddMealBottomSheet(candidates, objectKey);
        } else {
          _resetImageSelection();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analysis failed or no food recognized.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close upload dialog
        _resetImageSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showAddMealBottomSheet(
      List<FoodCandidate> candidates, String objectKey) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddMealBottomSheet(
        candidates: candidates,
        imageFile: _selectedImage!,
        objectKey: objectKey,
      ),
    );

    if (result != null) {
      final food = result['food'] as FoodCandidate;
      final mealType = result['mealType'] as MealType;

      final newEvent = MealEvent(
        food: food,
        mealType: mealType,
        timestamp: DateTime.now(),
        imageFile: XFile(objectKey),
      );

      setState(() {
        _mealEvents.add(newEvent);
      });

      try {
        await _uploadService.saveMealEvent(newEvent);
        if (mounted) {
          // 캐시를 무조건 비우고 새로 받아오도록
          final monthKey = _monthKey(_currentDay.year, _currentDay.month);
          FoodLogService.instance.monthCache.remove(monthKey);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${food.name} added as ${mealType.name}.'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadFoodLogsForDay(_currentDay);
        }
      } catch (e) {
        setState(() {
          _mealEvents.remove(newEvent);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save record: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    _resetImageSelection();
  }

  double totalCalories() =>
      _foodLogs.fold(0, (sum, log) => sum + (log.food.calories));
  double totalProtein() =>
      _foodLogs.fold(0, (sum, log) => sum + (log.food.protein));
  double totalFat() => _foodLogs.fold(0, (sum, log) => sum + (log.food.fat));
  double totalCarbs() =>
      _foodLogs.fold(0, (sum, log) => sum + (log.food.carbs));

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>().profile;
    final double dailyCalorieGoal =
        (userProfile?.targetCalories ?? 0).toDouble();
    final double dailyProteinGoal =
        (userProfile?.targetProtein ?? 0).toDouble();
    final double dailyFatGoal = (userProfile?.targetFats ?? 0).toDouble();
    final double dailyCarbGoal = (userProfile?.targetCarbs ?? 0).toDouble();

    final double leftCalories =
        (dailyCalorieGoal - totalCalories()).clamp(0, dailyCalorieGoal);
    final double leftProtein =
        (dailyProteinGoal - totalProtein()).clamp(0, dailyProteinGoal);
    final double leftFat = (dailyFatGoal - totalFat()).clamp(0, dailyFatGoal);
    final double leftCarbs =
        (dailyCarbGoal - totalCarbs()).clamp(0, dailyCarbGoal);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Snapit',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Do you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFoodLogsForDay(_currentDay),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    onPressed: () => _changeDay(-1),
                  ),
                  Text(
                    _getSimpleDate(_currentDay),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    onPressed: () => _changeDay(1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 아래 전체 스크롤 영역
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 남은 칼로리/영양 카드 타일
                      _buildSummaryCards(
                        dailyCalorieGoal: dailyCalorieGoal,
                        dailyProteinGoal: dailyProteinGoal,
                        dailyFatGoal: dailyFatGoal,
                        dailyCarbGoal: dailyCarbGoal,
                        leftCalories: leftCalories,
                        leftProtein: leftProtein,
                        leftFat: leftFat,
                        leftCarbs: leftCarbs,
                        totalCalories: totalCalories(),
                        totalProtein: totalProtein(),
                        totalFat: totalFat(),
                        totalCarbs: totalCarbs(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Recently eaten',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildBody(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _onCameraPressed,
        backgroundColor: const Color(0xFF006FFD),
        foregroundColor: Colors.white,
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.camera_alt, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadFoodLogsForDay(_currentDay),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_foodLogs.isEmpty) {
      return const Center(
        child: Text('No food logs yet. Add your first meal!'),
      );
    }

    return Column(
      children: _foodLogs.map((log) {
        // 영양 정보를 표시하는 작은 헬퍼 위젯 (가독성을 위해)
        Widget _buildNutrientInfo(String label, int value) {
          return Row(
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(width: 4),
              Text('${value}g',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 왼쪽 이미지 영역
              SizedBox(
                width: 90, // 이미지 너비를 직접 지정
                height: 90, // 이미지 높이를 직접 지정
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    log.imageFile.path, // log.imageUrl 등으로 변경될 수 있음
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12), // 이미지와 텍스트 사이 간격

              // 2. 오른쪽 텍스트 정보 영역 (남은 공간을 모두 차지)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2-1. 음식 이름과 시간
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            log.food.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              height: 1.3, // 줄간격
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade400, width: 1.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormat('hh:mm a').format(log.timestamp),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 2-2. 칼로리 정보
                    Text(
                      '${log.food.calories.toInt()} kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepOrange, // 강조색 사용
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2-3. 3대 영양소 정보
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Protein
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.blue, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${log.food.protein.toInt()}g',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        // Fat
                        Row(
                          children: [
                            Icon(Icons.circle, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${log.food.fat.toInt()}g',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        // Carbs
                        Row(
                          children: [
                            Icon(Icons.circle,
                                color: Colors.redAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${log.food.carbs.toInt()}g',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCards({
    required double dailyCalorieGoal,
    required double dailyProteinGoal,
    required double dailyFatGoal,
    required double dailyCarbGoal,
    required double leftCalories,
    required double leftProtein,
    required double leftFat,
    required double leftCarbs,
    required double totalCalories,
    required double totalProtein,
    required double totalFat,
    required double totalCarbs,
  }) {
    // 게이지: 먹은 비율, 텍스트: 남은 양
    final calorieRatio = (totalCalories / dailyCalorieGoal).clamp(0.0, 1.0);
    final proteinRatio = (totalProtein / dailyProteinGoal).clamp(0.0, 1.0);
    final fatRatio = (totalFat / dailyFatGoal).clamp(0.0, 1.0);
    final carbRatio = (totalCarbs / dailyCarbGoal).clamp(0.0, 1.0);

    return Column(
      children: [
        // 칼로리 반원 게이지 카드
        SizedBox(
          width: double.infinity,
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 반원 게이지
                        SizedBox(
                          width: 200,
                          height: 100,
                          child: CustomPaint(
                            painter: _SemiCircleProgressPainter(calorieRatio),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Text(
                              leftCalories.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text('kcal left',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 3대 영양소 원형 게이지 카드
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _NutrientCircleCard(
                label: 'Protein',
                left: leftProtein,
                unit: 'g',
                ratio: proteinRatio,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _NutrientCircleCard(
                label: 'Fat',
                left: leftFat,
                unit: 'g',
                ratio: fatRatio,
                color: Colors.amber,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _NutrientCircleCard(
                label: 'Carbs',
                left: leftCarbs,
                unit: 'g',
                ratio: carbRatio,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 반원 게이지 페인터
class _SemiCircleProgressPainter extends CustomPainter {
  final double ratio;
  _SemiCircleProgressPainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint fgPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    // 배경
    canvas.drawArc(rect, 3.14, 3.14, false, bgPaint);
    // 진행
    canvas.drawArc(rect, 3.14, 3.14 * ratio, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 원형 게이지 카드 위젯
class _NutrientCircleCard extends StatelessWidget {
  final String label;
  final double left;
  final String unit;
  final double ratio;
  final Color color;
  const _NutrientCircleCard({
    required this.label,
    required this.left,
    required this.unit,
    required this.ratio,
    required this.color,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: SizedBox(
        height: 130,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox.expand(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                          scale: 1.7,
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 5,
                            backgroundColor: color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          )),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Left', style: TextStyle(fontSize: 12)),
                          Text('${left.toInt()}$unit',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
