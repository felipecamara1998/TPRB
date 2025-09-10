import 'package:flutter/material.dart';

/// ====== DATA MODELS ======

enum TaskStatus { approved, pending, submitted, returned }

class ChapterProgressModel {
  final String title;
  final int done;
  final int total;
  ChapterProgressModel(this.title, this.done, this.total);
}

class TaskItemModel {
  final String number; // ex: "1.1"
  final String title; // ex: "Enclosed space entry briefing"
  final String chapter; // ex: "1 – Safety Basics"
  final DateTime? submittedAt;
  final TaskStatus status;

  TaskItemModel({
    required this.number,
    required this.title,
    required this.chapter,
    required this.status,
    this.submittedAt,
  });
}
