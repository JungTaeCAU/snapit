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

  String _getFormattedDate() {
    final now = DateTime.now();
    final day = now.day;
    String suffix;
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
        default:
          suffix = 'th';
      }
    }
    return DateFormat('MMMM d').format(now) + suffix + DateFormat(', yyyy').format(now);
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
          ),
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadImage,
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
      final List<FoodCandidate>? analysisResult =
          await _uploadService.uploadImage(_selectedImage!);
      if (mounted) {
        Navigator.of(context).pop(); // Close upload dialog
        if (analysisResult != null && analysisResult.isNotEmpty) {
          _showAddMealBottomSheet(analysisResult);
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

  void _showAddMealBottomSheet(List<FoodCandidate> candidates) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddMealBottomSheet(
        candidates: candidates,
        imageFile: _selectedImage!,
      ),
    );

    if (result != null) {
      final food = result['food'] as FoodCandidate;
      final mealType = result['mealType'] as MealType;

      final newEvent = MealEvent(
        food: food,
        mealType: mealType,
        timestamp: DateTime.now(),
        imageFile: _selectedImage!,
      );

      setState(() {
        _mealEvents.add(newEvent);
      });

      try {
        await _uploadService.saveMealEvent(newEvent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${food.name} added as ${mealType.name}.'),
              backgroundColor: Colors.green,
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                _getFormattedDate(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _mealEvents.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 40,
                            color: Color(0xFF006FFD),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Add a food you ate today!',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Press the camera button to start.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _mealEvents.length,
                      itemBuilder: (context, index) {
                        final event = _mealEvents[index];
                        final mealName = event.mealType.name
                                .substring(0, 1)
                                .toUpperCase() +
                            event.mealType.name.substring(1);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: kIsWeb
                                  ? NetworkImage(event.imageFile.path)
                                  : FileImage(File(event.imageFile.path))
                                      as ImageProvider,
                            ),
                            title: Text(
                              event.food.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                '$mealName · ${DateFormat.Hm().format(event.timestamp)}'),
                            trailing: Text(
                              '${event.food.calories} kcal',
                              style: const TextStyle(
                                  color: Color(0xFF006FFD),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
}
