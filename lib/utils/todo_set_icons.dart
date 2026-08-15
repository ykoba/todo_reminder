import 'package:flutter/material.dart';

/// Curated set of modern, outlined Material icons a user can pick to
/// represent a TodoSet (e.g. "保育園" → 学校, "掃除" → 掃除用具). Stored on
/// [TodoSet.icon] by key (not [IconData.codePoint], which isn't stable
/// across icon font/tree-shaking configurations).
const Map<String, IconData> todoSetIcons = {
  'checklist': Icons.checklist_outlined,
  'school': Icons.school_outlined,
  'home': Icons.home_outlined,
  'child_care': Icons.child_care_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'local_hospital': Icons.local_hospital_outlined,
  'fitness_center': Icons.fitness_center_outlined,
  'restaurant': Icons.restaurant_outlined,
  'cleaning_services': Icons.cleaning_services_outlined,
  'pets': Icons.pets_outlined,
  'work': Icons.work_outline,
  'book': Icons.book_outlined,
  'directions_run': Icons.directions_run_outlined,
  'local_laundry_service': Icons.local_laundry_service_outlined,
  'medication': Icons.medication_outlined,
  'savings': Icons.savings_outlined,
  'event': Icons.event_outlined,
  'directions_car': Icons.directions_car_outlined,
  'spa': Icons.spa_outlined,
  'star': Icons.star_outline,
};

/// Key used for TodoSets created before per-set icons existed, and the
/// fallback if a stored key is ever unrecognized (e.g. after removing an
/// icon from this set).
const String defaultTodoSetIconKey = 'checklist';

IconData todoSetIcon(String key) =>
    todoSetIcons[key] ?? todoSetIcons[defaultTodoSetIconKey]!;
