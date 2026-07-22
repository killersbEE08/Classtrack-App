import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum ExpenseCategory { food, transport, books, rent, fun, health, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.food => 'Food',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.books => 'Books',
        ExpenseCategory.rent => 'Rent',
        ExpenseCategory.fun => 'Fun',
        ExpenseCategory.health => 'Health',
        ExpenseCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ExpenseCategory.food => Icons.restaurant_rounded,
        ExpenseCategory.transport => Icons.directions_bus_rounded,
        ExpenseCategory.books => Icons.menu_book_rounded,
        ExpenseCategory.rent => Icons.home_rounded,
        ExpenseCategory.fun => Icons.movie_rounded,
        ExpenseCategory.health => Icons.favorite_rounded,
        ExpenseCategory.other => Icons.category_rounded,
      };

  Color get color => switch (this) {
        ExpenseCategory.food => AppColors.accent,
        ExpenseCategory.transport => AppColors.info,
        ExpenseCategory.books => AppColors.primary,
        ExpenseCategory.rent => AppColors.coral,
        ExpenseCategory.fun => AppColors.primaryLight,
        ExpenseCategory.health => AppColors.success,
        ExpenseCategory.other => AppColors.cancelled,
      };

  static ExpenseCategory parse(String? v) => ExpenseCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ExpenseCategory.other,
      );
}

/// A single expense entry. Stored at users/{uid}/expenses/{id}.
class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.createdAt,
  });

  Expense copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category.name,
        'date': Timestamp.fromDate(date),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: ExpenseCategoryX.parse(map['category'] as String?),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
