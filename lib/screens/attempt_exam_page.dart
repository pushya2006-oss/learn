import 'package:flutter/material.dart';
import 'dart:async';

class AttemptExamPage extends StatefulWidget {
  final Map<String, dynamic> examData;

  const AttemptExamPage({required this.examData});

  @override
  State<AttemptExamPage> createState() => _AttemptExamPageState();
}

class _AttemptExamPageState extends State<AttemptExamPage> {
  int currentQuestionIndex = 0;
  List<dynamic> questions = [];
  Map<int, String> userAnswers = {};
  
  late Timer _timer;
  int remainingSeconds = 0;
  bool isExamFinished = false;

  @override
  void initState() {
    super.initState();
    questions = widget.examData['questions'] ?? [];
    remainingSeconds = (widget.examData['duration'] ?? 60) * 60;
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        _timer.cancel();
        submitExam();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void submitExam() {
    if (isExamFinished) return;
    setState(() => isExamFinished = true);
    _timer.cancel();

    int score = 0;
    int correctAnswers = 0;
    int wrongAnswers = 0;

    for (int i = 0; i < questions.length; i++) {
        String correctOption = questions[i]['correctOption'].toString().trim().toLowerCase();
        String userAnswer = (userAnswers[i] ?? "").toString().trim().toLowerCase();
        
        if (userAnswer.isEmpty) {
            // Not attempted, no deduction if there isn't negative marking
        } else if (userAnswer == correctOption) {
            score += 1;
            correctAnswers++;
        } else {
            wrongAnswers++;
            // score -= 0; // optional negative marking
        }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Exam Finished!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Total Questions: ${questions.length}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text("Correct Answers: $correctAnswers", style: const TextStyle(fontSize: 16, color: Colors.green)),
              Text("Wrong Answers: $wrongAnswers", style: const TextStyle(fontSize: 16, color: Colors.red)),
              Text("Unattempted: ${questions.length - (correctAnswers + wrongAnswers)}", style: const TextStyle(fontSize: 16, color: Colors.orange)),
              const Divider(height: 30),
              Text("Total Score: $score / ${questions.length}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close exam page
              },
              child: const Text("Done"),
            )
          ],
        );
      }
    );
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  void goToNext() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    }
  }

  void goToPrevious() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("No questions found in this exam.")),
      );
    }

    final question = questions[currentQuestionIndex];
    final options = List<String>.from(question['options'] ?? []);
    final timerColor = remainingSeconds < 60 ? Colors.red : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examData['title'] ?? "Exam"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.timer, color: timerColor),
                  const SizedBox(width: 8),
                  Text(
                    formatTime(remainingSeconds),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Question ${currentQuestionIndex + 1} of ${questions.length}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                ElevatedButton(
                  onPressed: submitExam,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("Submit Exam"),
                ),
              ],
            ),
            const Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['question'] ?? "",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ...options.map((option) {
                      bool isSelected = userAnswers[currentQuestionIndex] == option;
                      return Card(
                        color: isSelected ? Colors.blue.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<String>(
                          value: option,
                          groupValue: userAnswers[currentQuestionIndex],
                          onChanged: isExamFinished
                              ? null
                              : (value) {
                                  setState(() {
                                    userAnswers[currentQuestionIndex] = value!;
                                  });
                                },
                          title: Text(option),
                          activeColor: Colors.blue,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: currentQuestionIndex > 0 ? goToPrevious : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Previous"),
                ),
                ElevatedButton.icon(
                  onPressed: currentQuestionIndex < questions.length - 1 ? goToNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Next"),
                  style: ElevatedButton.styleFrom(
                    iconAlignment: IconAlignment.end
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
