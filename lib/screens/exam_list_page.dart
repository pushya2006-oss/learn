import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../constants.dart';
import 'attempt_exam_page.dart';

class ExamListPage extends StatefulWidget {
  final String subject;
  final String year;
  final String semester;

  const ExamListPage({
    required this.subject,
    required this.year,
    required this.semester,
  });

  @override
  State<ExamListPage> createState() => _ExamListPageState();
}

class _ExamListPageState extends State<ExamListPage> {
  List<Map<String, dynamic>> exams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExams();
  }

  Future<void> loadExams() async {
    setState(() {
      isLoading = true;
    });

    try {
      final uri = Uri.parse("$baseUrl/getExams").replace(
        queryParameters: {
          "subject": widget.subject,
          "year": widget.year,
          "semester": widget.semester,
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> fetchedExams = jsonDecode(response.body);
        setState(() {
          exams = fetchedExams.map((e) => e as Map<String, dynamic>).toList();
          // Sort exams by scheduled time (newest first or upcoming first)
          exams.sort((a, b) {
            DateTime timeA = DateTime.parse(a['scheduledTime']);
            DateTime timeB = DateTime.parse(b['scheduledTime']);
            return timeA.compareTo(timeB);
          });
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to fetch exams: ${response.body}")),
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching exams: $e")),
        );
      }
    }
  }

  void attemptExam(Map<String, dynamic> exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttemptExamPage(examData: exam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scheduled Exams"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : exams.isEmpty
              ? Center(
                  child: Text(
                    "No exams scheduled yet for ${widget.subject}.",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadExams,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      DateTime scheduledTime = DateTime.parse(exam['scheduledTime']);
                      String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(scheduledTime);
                      bool canAttempt = DateTime.now().isAfter(scheduledTime);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exam['title'],
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text("Subject: ${exam['subject']}"),
                              Text("Date & Time: $formattedDate"),
                              Text("Duration: ${exam['duration']} mins"),
                              Text("Questions: ${exam['totalQuestions']}"),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: canAttempt ? () => attemptExam(exam) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canAttempt ? Colors.blue : Colors.grey,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(canAttempt ? "Attempt Exam" : "Not Started Yet"),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
