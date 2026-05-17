import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RCUploadBox extends StatefulWidget {
  final String title; // UI title
  final String folder; // Supabase bucket
  final Function(String url, String text, String status) onCompleted;

  const RCUploadBox({
    super.key,
    required this.title,
    required this.folder,
    required this.onCompleted,
  });

  @override
  State<RCUploadBox> createState() => _RCUploadBoxState();
}

class _RCUploadBoxState extends State<RCUploadBox> {
  bool isLoading = false;
  double progress = 0.0;
  String fileName = "";
  String message = "";

  // ---------------- REGEX CHECK ----------------
  final RegExp regNoPattern = RegExp(
    r'\b([A-Z]{2}[- ]?[0-9]{1,2}[- ]?[A-Z]{1,3}[- ]?[0-9]{3,4})\b',
    caseSensitive: false,
  );

  final RegExp chassisPattern = RegExp(
    r'(CHASSIS|CH NO)',
    caseSensitive: false,
  );

  final RegExp enginePattern = RegExp(r'(ENGINE|ENG NO)', caseSensitive: false);

  // ---------------- TEMP FILE ----------------
  Future<File> saveTempFile(Uint8List bytes, String ext) async {
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/temp_file.$ext");
    await file.writeAsBytes(bytes);
    return file;
  }

  // ---------------- OCR IMAGE ----------------
  Future<String> extractTextFromImage(File file) async {
    final recognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(file);
    final recognizedText = await recognizer.processImage(inputImage);
    await recognizer.close();
    return recognizedText.text;
  }

  // ---------------- OCR PDF ----------------
  Future<String> extractTextFromPdf(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text.trim().isEmpty ? "NO_TEXT_FOUND" : text;
  }

  // ---------------- VERIFY RC ----------------
  String analyzeRC(String text) {
    if (text == "NO_TEXT_FOUND") {
      return "⚠ No readable text found";
    }

    bool hasReg = regNoPattern.hasMatch(text);
    bool hasChassis = chassisPattern.hasMatch(text);
    bool hasEngine = enginePattern.hasMatch(text);

    if (hasReg && hasChassis && hasEngine) {
      return "✅ Valid RC Book";
    }

    if (hasReg) {
      return "⚠ RC found but incomplete details";
    }

    return "❌ Not a valid RC document";
  }

  // ---------------- PICK → VERIFY → UPLOAD ----------------
  Future<void> processUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (picked == null) return;

    setState(() {
      isLoading = true;
      progress = 0.15;
      fileName = picked.files.first.name;
      message = "Processing document...";
    });

    Uint8List bytes = picked.files.first.bytes!;
    String ext = picked.files.first.extension ?? "";
    String extractedText = "";

    // OCR
    if (ext == "pdf") {
      extractedText = await extractTextFromPdf(bytes);
    } else {
      final tempFile = await saveTempFile(bytes, ext);
      extractedText = await extractTextFromImage(tempFile);
    }

    final status = analyzeRC(extractedText);

    if (!status.contains("Valid")) {
      setState(() {
        isLoading = false;
        message = status;
      });
      return;
    }

    setState(() {
      progress = 0.6;
      message = "Uploading...";
    });

    final supabase = Supabase.instance.client;
    final filePath = "${DateTime.now().millisecondsSinceEpoch}.$ext";

    await supabase.storage.from(widget.folder).uploadBinary(filePath, bytes);

    final url = supabase.storage.from(widget.folder).getPublicUrl(filePath);

    setState(() {
      progress = 1.0;
      isLoading = false;
      message = "Upload completed";
    });

    widget.onCompleted(url, extractedText, status);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          InkWell(
            onTap: isLoading ? null : processUpload,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload, size: 42, color: Colors.blue),
                  SizedBox(height: 10),
                  Text("Drag & Drop or Click to Upload"),
                ],
              ),
            ),
          ),

          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(fileName, style: const TextStyle(fontSize: 13)),
          ],

          if (isLoading || progress == 1.0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 6),
            const SizedBox(height: 4),
            Text("${(progress * 100).toInt()}%"),
          ],

          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}
