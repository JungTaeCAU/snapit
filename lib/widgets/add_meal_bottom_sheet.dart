import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/food_candidate.dart';
import '../models/meal_event.dart';

class AddMealBottomSheet extends StatefulWidget {
  final List<FoodCandidate> candidates;
  final XFile imageFile;

  const AddMealBottomSheet({
    super.key,
    required this.candidates,
    required this.imageFile,
  });

  @override
  State<AddMealBottomSheet> createState() => _AddMealBottomSheetState();
}

class _AddMealBottomSheetState extends State<AddMealBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _manualNameController = TextEditingController();
  final _manualCaloriesController = TextEditingController();

  int? _selectedCandidateIndex;
  MealType? _selectedMealType;
  bool _isManualEntry = false;

  @override
  void dispose() {
    _manualNameController.dispose();
    _manualCaloriesController.dispose();
    super.dispose();
  }

  void _onAddPressed() {
    FoodCandidate? selectedFood;

    if (_isManualEntry) {
      if (_formKey.currentState!.validate()) {
        selectedFood = FoodCandidate(
          name: _manualNameController.text,
          calories: int.parse(_manualCaloriesController.text),
        );
      } else {
        return; // Don't proceed if form is invalid
      }
    } else if (_selectedCandidateIndex != null) {
      selectedFood = widget.candidates[_selectedCandidateIndex!];
    }

    if (selectedFood != null && _selectedMealType != null) {
      // Return the MealEvent without the image for now
      // The HomeScreen will add the image before saving
      Navigator.of(context).pop({
        'food': selectedFood,
        'mealType': _selectedMealType,
      });
    } else {
      // Show a snackbar or some feedback that all fields are required
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a food and a meal type.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentTime =
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentTime,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: kIsWeb
                  ? Image.network(widget.imageFile.path, fit: BoxFit.cover)
                  : Image.file(File(widget.imageFile.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'SELECT FOOD',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ...List.generate(widget.candidates.length, (index) {
            final candidate = widget.candidates[index];
            return RadioListTile<int>(
              title: Text(candidate.name),
              subtitle: Text('${candidate.calories} kcal'),
              value: index,
              groupValue: _isManualEntry ? null : _selectedCandidateIndex,
              onChanged: (value) {
                setState(() {
                  _selectedCandidateIndex = value;
                  _isManualEntry = false;
                });
              },
            );
          }),
          RadioListTile<bool>(
            title: const Text('Enter Manually'),
            value: true,
            groupValue: _isManualEntry,
            onChanged: (value) {
              setState(() {
                _isManualEntry = value!;
                _selectedCandidateIndex = null;
              });
            },
          ),
          if (_isManualEntry)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _manualNameController,
                      decoration: const InputDecoration(labelText: 'Food Name'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter a name'
                          : null,
                    ),
                    TextFormField(
                      controller: _manualCaloriesController,
                      decoration: const InputDecoration(labelText: 'Calories'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter calories';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'MEAL TYPE',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Wrap(
            spacing: 8.0,
            children: MealType.values.map((mealType) {
              return ChoiceChip(
                label: Text(
                    mealType.name.substring(0, 1).toUpperCase() +
                    mealType.name.substring(1)),
                selected: _selectedMealType == mealType,
                onSelected: (selected) {
                  setState(() {
                    _selectedMealType = selected ? mealType : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006FFD),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white),),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 