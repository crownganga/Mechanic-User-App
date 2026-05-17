import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class InsuranceUploadBox extends StatefulWidget {
  final String title; // UI title
  final String folder; // Supabase bucket
  final String? initialUrl; // 👈 ADD THIS
  final Function(String url, String text, String status) onCompleted;

  const InsuranceUploadBox({
    super.key,
    required this.title,
    required this.folder,
    required this.onCompleted,
    this.initialUrl,
  });

  @override
  State<InsuranceUploadBox> createState() => _InsuranceUploadBoxState();
}

class _InsuranceUploadBoxState extends State<InsuranceUploadBox> {
  bool isLoading = false;
  double progress = 0.0;
  String fileName = "";
  String message = "";

  // ---------------- REGEX ----------------
  final RegExp policyPattern = RegExp(
    r'(Policy\s*No|Policy\s*Number|POLICY)',
    caseSensitive: false,
  );

  final RegExp insurerPattern = RegExp(
    r'(Insurance|Insurer|Company|Provider)',
    caseSensitive: false,
  );

  final RegExp validityPattern = RegExp(
    r'(Valid\s*from|Valid\s*to|Expiry|Exp)',
    caseSensitive: false,
  );

  // ---------------- TEMP FILE ----------------
  Future<File> saveTemp(Uint8List bytes, String ext) async {
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/ins_temp.$ext");
    await file.writeAsBytes(bytes);
    return file;
  }

  // ---------------- OCR IMAGE ----------------
  Future<String> extractImageText(File file) async {
    final recognizer = TextRecognizer();
    final input = InputImage.fromFile(file);
    final result = await recognizer.processImage(input);
    await recognizer.close();
    return result.text;
  }

  // ---------------- OCR PDF ----------------
  Future<String> extractPdfText(Uint8List bytes) async {
    final doc = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return text.trim().isEmpty ? "NO_TEXT_FOUND" : text;
  }

  // ---------------- VERIFY ----------------
  String analyzeInsurance(String text) {
    if (text == "NO_TEXT_FOUND") return "⚠ No readable text found";

    bool hasPolicy = policyPattern.hasMatch(text);
    bool hasCompany = insurerPattern.hasMatch(text);
    bool hasValidity = validityPattern.hasMatch(text);

    if (hasPolicy && hasCompany && hasValidity) {
      return "✅ Valid Insurance";
    }

    if (hasPolicy || hasCompany) {
      return "⚠ Insurance found but incomplete";
    }

    return "❌ Not an Insurance Document";
  }

  // ---------------- PICK → VERIFY → UPLOAD ----------------
  Future<void> processInsurance() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ["pdf", "jpg", "jpeg", "png"],
    );

    if (picked == null) return;

    setState(() {
      isLoading = true;
      progress = 0.2;
      fileName = picked.files.first.name;
      message = "Verifying document...";
    });

    Uint8List bytes = picked.files.first.bytes!;
    String ext = picked.files.first.extension ?? "";
    String text = "";

    if (ext == "pdf") {
      text = await extractPdfText(bytes);
    } else {
      final temp = await saveTemp(bytes, ext);
      text = await extractImageText(temp);
    }

    final status = analyzeInsurance(text);

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
      message = "Insurance uploaded successfully!";
    });

    widget.onCompleted(url, text, status);
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
            onTap: isLoading ? null : processInsurance,
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
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: Colors.deepPurple,
              backgroundColor: Colors.grey.shade300,
            ),
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
