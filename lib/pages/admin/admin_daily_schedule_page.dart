// lib/pages/admin/admin_daily_schedule_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // تمت إضافته
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../main.dart'; // For TextDirection

// يمكنك نسخ AppConstants هنا مؤقتًا أو استيرادها إذا كانت في ملف منفصل

class AdminDailySchedulePage extends StatefulWidget {
  const AdminDailySchedulePage({super.key});

  @override
  State<AdminDailySchedulePage> createState() => _AdminDailySchedulePageState();
}

class _AdminDailySchedulePageState extends State<AdminDailySchedulePage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<DocumentSnapshot> _availableEngineers = [];
  List<DocumentSnapshot> _availableProjects = [];
  bool _isLoadingUsersAndProjects = true;

  List<DocumentSnapshot> _scheduledTasksForSelectedDay = []; // <-- متغير جديد
  bool _isLoadingTasks = false; // <-- متغير جديد

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsersAndProjects = true;
    });
    // await _fetchCurrentAdminId(); // إذا احتجت إليه
    await Future.wait([
      _fetchAvailableEngineers(),
      _fetchAvailableProjects(),
    ]);
    if (mounted) {
      setState(() {
        _isLoadingUsersAndProjects = false;
      });
      _fetchTasksForDay(_selectedDay); // جلب المهام لليوم المحدد مبدئيًا
    }
  }

  Future<void> _fetchAvailableEngineers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _availableEngineers = snapshot.docs;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching engineers: $e");
      }
    }
  }

  Future<void> _fetchAvailableProjects() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _availableProjects = snapshot.docs;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching projects: $e");
      }
    }
  }

  Future<void> _fetchTasksForDay(DateTime day) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTasks = true;
    });
    try {
      DateTime startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
      DateTime endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('daily_schedules')
          .where('scheduleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _scheduledTasksForSelectedDay = snapshot.docs;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching tasks for day: $e");
        setState(() {
          _isLoadingTasks = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل المهام: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
    if (_availableEngineers.isEmpty && _availableProjects.isEmpty && _isLoadingUsersAndProjects) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحميل بيانات المهندسين والمشاريع، يرجى الانتظار...')),
      );
      return;
    }
    if (_availableEngineers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مهندسون متاحون. يرجى إضافتهم أولاً.')),
      );
      return;
    }
    if (_availableProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مشاريع متاحة. يرجى إضافتها أولاً.')),
      );
      return;
    }

    final _formKeyDialog = GlobalKey<FormState>(); // تغيير اسم المفتاح لتمييزه
    String? selectedEngineerId;
    String? selectedProjectId;
    final taskTitleController = TextEditingController();
    final taskDescriptionController = TextEditingController();
    bool isSavingTask = false;

    final currentAdminUser = FirebaseAuth.instance.currentUser;
    String adminName = "المسؤول";
    if (currentAdminUser != null) {
      try {
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentAdminUser.uid).get();
        if (adminDoc.exists) {
          adminName = (adminDoc.data() as Map<String, dynamic>)['name'] ?? "المسؤول";
        }
      } catch (e) {
        print("Error fetching admin name for dialog: $e");
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: !isSavingTask,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('إضافة مهمة جديدة ليوم ${DateFormat('dd/MM/yyyy', 'ar_SA').format(_selectedDay)}'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'اختر المهندس', border: OutlineInputBorder()),
                        value: selectedEngineerId,
                        isExpanded: true,
                        hint: const Text('حدد المهندس'),
                        items: _availableEngineers.map((doc) {
                          final engineer = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(engineer['name'] ?? 'مهندس غير مسمى'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedEngineerId = value;
                          });
                        },
                        validator: (value) => value == null ? 'الرجاء اختيار المهندس' : null,
                      ),
                      const SizedBox(height: AppConstants.paddingMedium),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'اختر المشروع', border: OutlineInputBorder()),
                        value: selectedProjectId,
                        isExpanded: true,
                        hint: const Text('حدد المشروع'),
                        items: _availableProjects.map((doc) {
                          final project = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(project['name'] ?? 'مشروع غير مسمى'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedProjectId = value;
                          });
                        },
                        validator: (value) => value == null ? 'الرجاء اختيار المشروع' : null,
                      ),
                      const SizedBox(height: AppConstants.paddingMedium),
                      TextFormField(
                        controller: taskTitleController,
                        decoration: const InputDecoration(labelText: 'عنوان المهمة', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال عنوان للمهمة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.paddingMedium),
                      TextFormField(
                        controller: taskDescriptionController,
                        decoration: const InputDecoration(labelText: 'وصف المهمة وتفاصيلها', border: OutlineInputBorder()),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال وصف للمهمة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('إلغاء'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton.icon(
                  icon: isSavingTask
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(isSavingTask ? 'جاري الحفظ...' : 'حفظ المهمة', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  onPressed: isSavingTask ? null : () async {
                    if (_formKeyDialog.currentState!.validate()) {
                      setDialogState(() => isSavingTask = true);

                      final engineerDoc = _availableEngineers.firstWhere((doc) => doc.id == selectedEngineerId);
                      final engineerName = (engineerDoc.data() as Map<String, dynamic>)['name'] ?? 'مهندس غير مسمى';

                      final projectDoc = _availableProjects.firstWhere((doc) => doc.id == selectedProjectId);
                      final projectName = (projectDoc.data() as Map<String, dynamic>)['name'] ?? 'مشروع غير مسمى';

                      try {
                        // إضافة المهمة الجديدة إلى Firestore
                        DocumentReference docRef = await FirebaseFirestore.instance.collection('daily_schedules').add({
                          'engineerId': selectedEngineerId,
                          'engineerName': engineerName,
                          'projectId': selectedProjectId,
                          'projectName': projectName,
                          'taskTitle': taskTitleController.text,
                          'taskDescription': taskDescriptionController.text,
                          'scheduleDate': Timestamp.fromDate(DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)),
                          'status': 'pending',
                          'adminId': currentAdminUser?.uid,
                          'adminName': adminName,
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        // إرسال إشعار للمهندس
                        // تأكد من أن دالة sendNotification معرفة بشكل صحيح في main.dart
                        // أو في ملف يمكن الوصول إليه
                        if (mounted && selectedEngineerId != null) {
                          // استدعاء دالة الإشعار العامة
                          sendNotification(
                            recipientUserId: selectedEngineerId!,
                            title: 'مهمة جديدة في جدولك',
                            body: 'تم تعيينك لمشروع "$projectName" بمهمة: "${taskTitleController.text}" ليوم ${DateFormat('dd/MM/yyyy', 'ar_SA').format(_selectedDay)}.',
                            type: 'new_daily_task',
                            projectId: selectedProjectId,
                            itemId: docRef.id, // معرّف المهمة المضافة حديثًا
                            senderName: adminName,
                          );
                        }


                        ScaffoldMessenger.of(this.context).showSnackBar( // استخدام this.context لـ SnackBar الرئيسي
                          const SnackBar(content: Text('تم حفظ المهمة بنجاح!'), backgroundColor: Colors.green),
                        );
                        Navigator.of(dialogContext).pop();
                        _fetchTasksForDay(_selectedDay);

                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('حدث خطأ أثناء حفظ المهمة: $e'), backgroundColor: Colors.red),
                        );
                      } finally {
                        setDialogState(() => isSavingTask = false);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _confirmDeleteTask(String taskId, String taskTitle) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المهمة "$taskTitle"؟'),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
              child: const Text('حذف'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('daily_schedules').doc(taskId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المهمة بنجاح'), backgroundColor: Colors.green),
        );
        _fetchTasksForDay(_selectedDay); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف المهمة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildScheduledTasksList() {
    if (_isLoadingTasks) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(color: AppConstants.primaryColor),
      ));
    }
    if (_scheduledTasksForSelectedDay.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'لا توجد مهام مجدولة لهذا اليوم.',
            style: TextStyle(fontSize: 16, color: AppConstants.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall),
      itemCount: _scheduledTasksForSelectedDay.length,
      itemBuilder: (context, index) {
        final taskDoc = _scheduledTasksForSelectedDay[index];
        final taskData = taskDoc.data() as Map<String, dynamic>;

        final String engineerName = taskData['engineerName'] ?? 'مهندس غير محدد';
        final String projectName = taskData['projectName'] ?? 'مشروع غير محدد';
        final String taskTitle = taskData['taskTitle'] ?? 'مهمة بدون عنوان';
        final String taskDescription = taskData['taskDescription'] ?? 'لا يوجد وصف';
        // final Timestamp? scheduleTimestamp = taskData['scheduleDate'] as Timestamp?;
        // final String scheduleDateFormatted = scheduleTimestamp != null
        //     ? DateFormat('dd/MM/yyyy', 'ar_SA').format(scheduleTimestamp.toDate())
        //     : 'تاريخ غير محدد';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall, horizontal: AppConstants.paddingMedium - AppConstants.paddingSmall),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              child: const Icon(Icons.task_alt_rounded, color: AppConstants.primaryColor),
            ),
            title: Text(taskTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('المهندس: $engineerName', style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                Text('المشروع: $projectName', style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                if (taskDescription.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('الوصف: $taskDescription', style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis,),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor),
              onPressed: () {
                _confirmDeleteTask(taskDoc.id, taskTitle);
              },
            ),
            onTap: () {
              // Future: Open task details or edit dialog
            },
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة الجداول اليومية للمهندسين',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20),
          ),
          backgroundColor: AppConstants.primaryColor,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor, AppConstants.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 3,
          centerTitle: true,
        ),
        body: _isLoadingUsersAndProjects
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : Column(
          children: [
            Card(
              margin: const EdgeInsets.all(AppConstants.paddingMedium),
              elevation: 3,
              shadowColor: AppConstants.primaryColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                child: TableCalendar(
                  locale: 'ar_SA',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.saturday,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppConstants.primaryLight.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppConstants.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    weekendTextStyle: TextStyle(color: Colors.red[600]),
                    outsideDaysVisible: false,
                    markersAlignment: Alignment.bottomCenter,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: AppConstants.primaryColor),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: AppConstants.primaryColor),
                    formatButtonTextStyle: const TextStyle(color: Colors.white),
                    formatButtonDecoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        _fetchTasksForDay(selectedDay); // جلب المهام لليوم الجديد
                      });
                    }
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    // جلب مهام الشهر الأول عند تغيير الصفحة إذا كان _selectedDay لا يزال في الشهر السابق
                    if (!isSameMonth(_selectedDay, focusedDay)) {
                      // اختر اليوم الأول من الشهر المركز عليه
                      DateTime newSelectedDayForMonth = DateTime(focusedDay.year, focusedDay.month, 1);
                      // تأكد من أن اليوم الأول ليس في الماضي إذا كان التقويم يبدأ من اليوم
                      if (newSelectedDayForMonth.isBefore(DateTime.utc(2020,1,1))) {
                        newSelectedDayForMonth = DateTime.utc(2020,1,1);
                      } else if (newSelectedDayForMonth.isAfter(DateTime.utc(2030,12,31))) {
                        newSelectedDayForMonth = DateTime.utc(2030,12,31);
                      }

                      // إذا كان اليوم المحدد سابقًا ليس في نفس الشهر الجديد، قم بتحديث selectedDay
                      // لمنع بقاء التحديد على يوم من شهر سابق عند تصفح الشهور.
                      // هذا يضمن أن _fetchTasksForDay سيتم استدعاؤه دائمًا لليوم المعروض أو يوم من الشهر المعروض.
                      if (!isSameMonth(_selectedDay, focusedDay)) {
                        setState(() {
                          _selectedDay = newSelectedDayForMonth;
                          // لا حاجة لتحديث _focusedDay هنا لأنه تم تحديثه بالفعل بواسطة onPageChanged
                        });
                      }
                    }
                    _fetchTasksForDay(_selectedDay); // جلب المهام لليوم المحدد الحالي أو الجديد
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall, horizontal: AppConstants.paddingMedium),
              child: Text(
                "المهام المجدولة ليوم: ${DateFormat('EEEE, dd MMMM yyyy', 'ar_SA').format(_selectedDay)}",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
              ),
            ),
            const Divider(indent: 20, endIndent: 20),
            Expanded(
              child: _buildScheduledTasksList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isLoadingUsersAndProjects ? null : _showAddTaskDialog,
          label: const Text('إضافة مهمة لليوم المحدد', style: TextStyle(color: Colors.white)),
          icon: const Icon(Icons.add_task_rounded, color: Colors.white),
          backgroundColor: AppConstants.primaryColor,
        ),
      ),
    );
  }

  // دالة للتحقق إذا كان اليومان في نفس الشهر والسنة
  bool isSameMonth(DateTime dayA, DateTime dayB) {
    return dayA.year == dayB.year && dayA.month == dayB.month;
  }
}