// lib/models/evaluation_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';

class EvaluationSettings {
  final double workingHoursWeight;
  final double tasksCompletedWeight;
  final double activityRateWeight;
  final double productivityWeight;
  final bool enableMonthlyEvaluation;
  final bool enableYearlyEvaluation;
  final bool sendNotifications;

  EvaluationSettings({
    required this.workingHoursWeight,
    required this.tasksCompletedWeight,
    required this.activityRateWeight,
    required this.productivityWeight,
    required this.enableMonthlyEvaluation,
    required this.enableYearlyEvaluation,
    required this.sendNotifications,
  });

  factory EvaluationSettings.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    return EvaluationSettings(
      workingHoursWeight: (data['workingHoursWeight'] as num?)?.toDouble() ?? 40.0,
      tasksCompletedWeight: (data['tasksCompletedWeight'] as num?)?.toDouble() ?? 30.0,
      activityRateWeight: (data['activityRateWeight'] as num?)?.toDouble() ?? 20.0,
      productivityWeight: (data['productivityWeight'] as num?)?.toDouble() ?? 10.0,
      enableMonthlyEvaluation: data['enableMonthlyEvaluation'] as bool? ?? false,
      enableYearlyEvaluation: data['enableYearlyEvaluation'] as bool? ?? false,
      sendNotifications: data['sendNotifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workingHoursWeight': workingHoursWeight,
      'tasksCompletedWeight': tasksCompletedWeight,
      'activityRateWeight': activityRateWeight,
      'productivityWeight': productivityWeight,
      'enableMonthlyEvaluation': enableMonthlyEvaluation,
      'enableYearlyEvaluation': enableYearlyEvaluation,
      'sendNotifications': sendNotifications,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class EngineerEvaluation {
  final String engineerId;
  final String engineerName;
  final String periodType;
  final String periodIdentifier;
  final double totalScore;
  final Map<String, double> criteriaScores;
  final Map<String, dynamic> rawMetrics;
  final DateTime evaluationDate;

  EngineerEvaluation({
    required this.engineerId,
    required this.engineerName,
    required this.periodType,
    required this.periodIdentifier,
    required this.totalScore,
    required this.criteriaScores,
    required this.rawMetrics,
    required this.evaluationDate,
  });

  factory EngineerEvaluation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    // === بداية التعديل ===
    // التحويل الصريح للقيم الرقمية إلى double في criteriaScores
    Map<String, double> parsedCriteriaScores = {};
    if (data['criteriaScores'] is Map) {
      (data['criteriaScores'] as Map).forEach((key, value) {
        if (value is num) { // إذا كانت القيمة رقماً (سواء int أو double)
          parsedCriteriaScores[key.toString()] = value.toDouble(); // حولها إلى double
        } else {
          parsedCriteriaScores[key.toString()] = 0.0; // قيمة افتراضية إذا لم تكن رقماً
        }
      });
    }
    // === نهاية التعديل ===

    return EngineerEvaluation(
      engineerId: data['engineerId'] as String? ?? '',
      engineerName: data['engineerName'] as String? ?? 'غير معروف',
      periodType: data['periodType'] as String? ?? 'monthly',
      periodIdentifier: data['periodIdentifier'] as String? ?? '',
      totalScore: (data['totalScore'] as num?)?.toDouble() ?? 0.0,
      criteriaScores: parsedCriteriaScores, // استخدم الخريطة المحولة
      rawMetrics: Map<String, dynamic>.from(data['rawMetrics'] ?? {}),
      evaluationDate: (data['evaluationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'engineerId': engineerId,
      'engineerName': engineerName,
      'periodType': periodType,
      'periodIdentifier': periodIdentifier,
      'totalScore': totalScore,
      'criteriaScores': criteriaScores,
      'rawMetrics': rawMetrics,
      'evaluationDate': evaluationDate,
    };
  }
}

