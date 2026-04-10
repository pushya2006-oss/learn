import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // ✅ works on Android, iOS, Web
import 'dart:convert';

import '../constants.dart'; // ✅ single baseUrl

class ResourcePage extends StatefulWidget {
  final String type;      // "pyq" or "external"
  final String subject;
  final String year;
  final String semester;

  const ResourcePage({
    required this.type,
    required this.subject,
    required this.year,
    required this.semester,
  });

  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  List resources = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchResources();
  }

  Future<void> fetchResources() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse("$baseUrl/getResources/filter").replace(
        queryParameters: {
          "subject": widget.subject,
          "type": widget.type,
          "year": widget.year,
          "semester": widget.semester,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        setState(() {
          resources = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load. Status: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Connection error. Check your internet.";
        isLoading = false;
      });
    }
  }

  // ✅ Works on Android, iOS, and Web (no dart:html needed)
  Future<void> openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open link")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPyq = widget.type == "pyq";
    final pageTitle = isPyq ? "Previous Year Papers" : "External Resources";

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.subject} - $pageTitle"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: fetchResources,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : resources.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPyq ? Icons.folder_open : Icons.link_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No ${isPyq ? 'question papers' : 'external resources'} found\nfor ${widget.subject} - ${widget.semester}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchResources,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: resources.length,
                        itemBuilder: (context, index) {
                          final item = resources[index];
                          final isExternal = item['type'] == 'external';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isExternal ? Colors.blue : Colors.red,
                                child: Icon(
                                  isExternal ? Icons.open_in_browser : Icons.picture_as_pdf,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                item['title'] ?? "Untitled",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: isPyq &&
                                      item['exam_year'] != null &&
                                      item['exam_year'] != ""
                                  ? Text("${widget.semester}  •  Exam Year: ${item['exam_year']}")
                                  : Text(widget.semester),
                              trailing: Icon(
                                isExternal ? Icons.open_in_new : Icons.download,
                                color: isExternal ? Colors.blue : Colors.indigo,
                              ),
                              onTap: () => openLink(item['link']),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}