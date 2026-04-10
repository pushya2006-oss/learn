import 'package:flutter/material.dart';
import 'resource_page.dart';
import 'exam_list_page.dart';

class OptionsPage extends StatelessWidget {
  final String subject;
  final String year;       // ✅ NEW: passed from SubjectPage
  final String semester;   // ✅ NEW: passed from SubjectPage

  const OptionsPage({
    required this.subject,
    required this.year,
    required this.semester,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subject)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.history_edu),
              ),
              title: const Text(
                "Previous Year Papers",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("PYQ PDFs for exam prep"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResourcePage(
                      type: "pyq",
                      subject: subject,
                      year: year,           // ✅ pass year
                      semester: semester,   // ✅ pass semester
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.link),
              ),
              title: const Text(
                "External Resources",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Reference links & study material"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResourcePage(
                      type: "external",
                      subject: subject,
                      year: year,
                      semester: semester,
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.assignment, color: Colors.white),
              ),
              title: const Text(
                "Examinations",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Attempt scheduled MCQ exams"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamListPage(
                      subject: subject,
                      year: year,
                      semester: semester,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}