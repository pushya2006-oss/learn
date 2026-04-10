import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class AdminExamPage extends StatefulWidget {
  @override
  State<AdminExamPage> createState() => _AdminExamPageState();
}

class _AdminExamPageState extends State<AdminExamPage> {
  final titleController = TextEditingController();
  final durationController = TextEditingController();
  
  String selectedYear = "1st Year";
  String selectedSemester = "Semester 1";
  String selectedSubject = "Maths 1";
  
  DateTime? scheduledDate;
  TimeOfDay? scheduledTime;
  
  List<int>? fileBytes;
  String? fileName;
  bool isLoading = false;
  String uploadStatus = "";
  
  final List<String> years = ["1st Year", "2nd Year", "3rd Year", "4th Year"];

  final Map<String, List<String>> yearSemesters = {
    "1st Year": ["Semester 1", "Semester 2"],
    "2nd Year": ["Semester 3", "Semester 4"],
    "3rd Year": ["Semester 5", "Semester 6"],
    "4th Year": ["Semester 7", "Semester 8"],
  };

  final Map<String, List<String>> semesterSubjects = {
    "Semester 1": ["Maths 1", "Physics", "Chemistry", "C Programming"],
    "Semester 2": ["Maths 2", "Electrical", "Mechanics", "Python"],
    "Semester 3": ["Data Structures", "Digital Logic", "Maths 3"],
    "Semester 4": ["Operating Systems", "DBMS", "OOP"],
    "Semester 5": ["Computer Networks", "AI", "Software Engineering"],
    "Semester 6": ["Machine Learning", "Compiler Design"],
    "Semester 7": ["Cloud Computing", "Big Data"],
    "Semester 8": ["Project Work"],
  };

  void onYearChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedYear = value;
      selectedSemester = yearSemesters[value]!.first;
      selectedSubject = semesterSubjects[selectedSemester]!.first;
    });
  }

  void onSemesterChanged(String? value) {
    if (value == null) return;
    setState(() {
      selectedSemester = value;
      selectedSubject = semesterSubjects[value]!.first;
    });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => scheduledDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => scheduledTime = picked);
    }
  }

  Future<void> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        fileBytes = result.files.single.bytes!;
        fileName = result.files.single.name;
        uploadStatus = "";
      });
    }
  }

  Future<void> scheduleExam() async {
    if (titleController.text.trim().isEmpty || 
        durationController.text.trim().isEmpty ||
        scheduledDate == null ||
        scheduledTime == null ||
        fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select an Excel file")),
      );
      return;
    }

    setState(() { isLoading = true; uploadStatus = ""; });

    try {
      // Parse Excel file
      var excel = Excel.decodeBytes(fileBytes!);
      List<Map<String, dynamic>> questions = [];
      String? parsedError;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;
        if (sheet.rows.length <= 1) continue; // Skip if empty or only header
        
        bool isHeader = true;
        for (var row in sheet.rows) {
          if (isHeader) {
            isHeader = false;
            continue;
          }
          
          if (row[0]?.value == null) continue; // Skip empty rows

          try {
            String question = row[0]?.value.toString() ?? "";
            String optionA = row[1]?.value.toString() ?? "";
            String optionB = row[2]?.value.toString() ?? "";
            String optionC = row[3]?.value.toString() ?? "";
            String optionD = row[4]?.value.toString() ?? "";
            String correctOption = row[5]?.value.toString() ?? "";

            if (question.isNotEmpty && correctOption.isNotEmpty) {
              questions.add({
                "question": question,
                "options": [optionA, optionB, optionC, optionD],
                "correctOption": correctOption,
              });
            }
          } catch (e) {
            parsedError = "Error parsing row: $e";
          }
        }
        break; // Only read first sheet
      }

      if (questions.isEmpty) {
        throw Exception(parsedError ?? "No valid questions found. Check Excel format.");
      }

      final scheduleDateTime = DateTime(
        scheduledDate!.year,
        scheduledDate!.month,
        scheduledDate!.day,
        scheduledTime!.hour,
        scheduledTime!.minute,
      );

      final examId = DateTime.now().millisecondsSinceEpoch.toString();

      final examData = {
        "id": examId,
        "title": titleController.text.trim(),
        "year": selectedYear,
        "semester": selectedSemester,
        "subject": selectedSubject,
        "duration": int.tryParse(durationController.text.trim()) ?? 60,
        "scheduledTime": scheduleDateTime.toIso8601String(),
        "totalQuestions": questions.length,
        "questions": questions,
      };

      // Send to backend
      final prefs = await SharedPreferences.getInstance();
      final adminToken = prefs.getString("admin_token");
      if (adminToken == null) {
        throw Exception("Admin token missing. Try logging in again.");
      }

      final response = await http.post(
        Uri.parse("$baseUrl/scheduleExam"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": adminToken,
        },
        body: jsonEncode(examData),
      );

      if (response.statusCode != 200) {
         throw Exception(response.body);
      }

      setState(() {
        uploadStatus = "✅ Exam scheduled successfully!";
        fileBytes = null;
        fileName = null;
        titleController.clear();
        durationController.clear();
        scheduledDate = null;
        scheduledTime = null;
      });

      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Exam scheduled successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() => uploadStatus = "❌ Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesters = yearSemesters[selectedYear]!;
    final subjects = semesterSubjects[selectedSemester]!;

    final formattedDate = scheduledDate != null 
        ? DateFormat('yyyy-MM-dd').format(scheduledDate!) 
        : "Select Date";
    final formattedTime = scheduledTime != null 
        ? scheduledTime!.format(context) 
        : "Select Time";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule MCQ Exam"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──
            const Text("Exam Title", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "e.g. Mid Term Exam",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Year, Semester, Subject ──
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder()),
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: onYearChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSemester,
                    decoration: const InputDecoration(labelText: "Semester", border: OutlineInputBorder()),
                    items: semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: onSemesterChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
             DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder()),
                items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => selectedSubject = v!),
              ),
            const SizedBox(height: 16),

            // ── Timing and Duration ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(formattedDate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                   child: ElevatedButton.icon(
                    onPressed: pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(formattedTime),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const Text("Duration (minutes)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
             TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "e.g. 60",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ── File Picker ──
            const Text("Upload Questions (Excel File .xlsx)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Format: Question | Option A | Option B | Option C | Option D | Correct Option", 
               style: TextStyle(fontSize: 12, color: Colors.brown)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: fileName != null ? Colors.green : Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: fileName != null ? Colors.green.shade50 : Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  Icon(
                    fileName != null ? Icons.table_chart : Icons.upload_file,
                    size: 40,
                    color: fileName != null ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName ?? "No file selected",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fileName != null ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: pickExcelFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text("Pick Excel File"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Setup Button ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : scheduleExam,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.event_available),
                label: Text(isLoading ? "Scheduling..." : "Schedule Exam"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (uploadStatus.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  uploadStatus,
                  style: TextStyle(
                    color: uploadStatus.startsWith("✅") ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
