import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../constants.dart'; // ✅ single baseUrl
import 'admin_login_page.dart';
import 'admin_exam_page.dart'; // Import for exam scheduling

class AdminPage extends StatefulWidget {
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<int>? fileBytes;
  String? fileName;
  bool isLoading = false;
  String uploadStatus = "";
  String? adminToken;

  final titleController = TextEditingController();
  final examYearController = TextEditingController();
  final externalLinkController = TextEditingController();

  String selectedYear = "1st Year";
  String selectedSemester = "Semester 1";
  String selectedSubject = "Maths 1";
  String selectedType = "pyq";

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

  final List<String> types = ["pyq", "external"];

  @override
  void initState() {
    super.initState();
    loadAdminToken();
  }

  Future<void> loadAdminToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("admin_token");

    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminLoginPage()),
      );
      return;
    }

    setState(() => adminToken = token);
  }

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

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        fileBytes = result.files.single.bytes!;
        fileName = result.files.single.name;
        if (titleController.text.isEmpty) {
          titleController.text = result.files.single.name
              .replaceAll('.pdf', '')
              .replaceAll('_', ' ');
        }
      });
    }
  }

  Future<void> uploadPDF() async {
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a PDF file first")),
      );
      return;
    }
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a title")),
      );
      return;
    }

    setState(() { isLoading = true; uploadStatus = ""; });

    try {
      final req = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));
      req.headers['Authorization'] = adminToken!;

      req.files.add(http.MultipartFile.fromBytes(
        "file",
        fileBytes!,
        filename: fileName!,
      ));

      req.fields['title'] = titleController.text.trim();
      req.fields['subject'] = selectedSubject;
      req.fields['type'] = selectedType;
      req.fields['year'] = selectedYear;
      req.fields['semester'] = selectedSemester;
      req.fields['exam_year'] = examYearController.text.trim();

      final response = await req.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          uploadStatus = "✅ Uploaded successfully!";
          fileBytes = null;
          fileName = null;
          titleController.clear();
          examYearController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ File uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        _handleExpiredToken();
      } else {
        setState(() => uploadStatus = "❌ Upload failed: $responseBody");
      }
    } catch (e) {
      setState(() => uploadStatus = "❌ Error: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> uploadExternalLink() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a title")),
      );
      return;
    }

    final url = externalLinkController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the external link")),
      );
      return;
    }
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link must start with http:// or https://")),
      );
      return;
    }

    setState(() { isLoading = true; uploadStatus = ""; });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/addLink"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": adminToken!,
        },
        body: jsonEncode({
          "title": titleController.text.trim(),
          "subject": selectedSubject,
          "type": "external",
          "link": url,
          "year": selectedYear,
          "semester": selectedSemester,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          uploadStatus = "✅ Link saved successfully!";
          titleController.clear();
          externalLinkController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Link saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        _handleExpiredToken();
      } else {
        setState(() => uploadStatus = "❌ Failed: ${response.body}");
      }
    } catch (e) {
      setState(() => uploadStatus = "❌ Error: $e");
    }

    setState(() => isLoading = false);
  }

  void _handleExpiredToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("admin_token");
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesters = yearSemesters[selectedYear]!;
    final subjects = semesterSubjects[selectedSemester]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            tooltip: "Schedule Exam",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminExamPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Admin Logout",
            onPressed: _handleExpiredToken,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──
            const Text("Title", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Resource title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Type ──
            const Text("Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: types
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(
                              t == "pyq" ? Icons.picture_as_pdf : Icons.link,
                              color: t == "pyq" ? Colors.red : Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(t == "pyq"
                                ? "PYQ - Previous Year Paper"
                                : "External Resource (Link)"),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                selectedType = v!;
                fileBytes = null;
                fileName = null;
                externalLinkController.clear();
                uploadStatus = "";
              }),
            ),
            const SizedBox(height: 16),

            // ── Year ──
            const Text("Year", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedYear,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: onYearChanged,
            ),
            const SizedBox(height: 16),

            // ── Semester ──
            const Text("Semester", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedSemester,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: onSemesterChanged,
            ),
            const SizedBox(height: 16),

            // ── Subject ──
            const Text("Subject", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedSubject,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => selectedSubject = v!),
            ),
            const SizedBox(height: 16),

            // ── PYQ: Exam Year + File Picker ──
            if (selectedType == "pyq") ...[
              const Text("Exam Year", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: examYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "e.g. 2023",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text("PDF File", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
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
                      fileName != null ? Icons.picture_as_pdf : Icons.upload_file,
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
                      onPressed: pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Pick PDF"),
                    ),
                  ],
                ),
              ),
            ],

            // ── External: URL field ──
            if (selectedType == "external") ...[
              const Text("External Link", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: externalLinkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: "https://www.youtube.com/watch?v=...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 8),
              const Text("Common sources:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _hintChip("YouTube", "https://www.youtube.com/"),
                  _hintChip("NPTEL", "https://nptel.ac.in/"),
                  _hintChip("MIT OCW", "https://ocw.mit.edu/"),
                  _hintChip("GeeksForGeeks", "https://www.geeksforgeeks.org/"),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Upload / Save Button ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : selectedType == "pyq"
                        ? uploadPDF
                        : uploadExternalLink,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(selectedType == "pyq" ? Icons.cloud_upload : Icons.save),
                label: Text(isLoading
                    ? "Saving..."
                    : selectedType == "pyq"
                        ? "Upload PDF"
                        : "Save Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedType == "pyq" ? Colors.indigo : Colors.blue,
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
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hintChip(String label, String url) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => externalLinkController.text = url,
    );
  }
}