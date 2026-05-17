import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FileUploadBox extends StatefulWidget {
  final String folder;
  final Function(String url) onUploadDone;

  const FileUploadBox({
    super.key,
    required this.folder,
    required this.onUploadDone,
  });

  @override
  State<FileUploadBox> createState() => _FileUploadBoxState();
}

class _FileUploadBoxState extends State<FileUploadBox> {
  double progress = 0;
  bool isUploading = false;

  Future<void> uploadFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);

    if (picked == null) return;

    Uint8List bytes = picked.files.first.bytes!;
    String ext = picked.files.first.extension ?? "file";
    String name = "${DateTime.now().millisecondsSinceEpoch}.$ext";

    setState(() {
      isUploading = true;
      progress = 20;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase.storage.from(widget.folder).uploadBinary(name, bytes);

      setState(() => progress = 100);

      final url = supabase.storage.from(widget.folder).getPublicUrl(name);

      widget.onUploadDone(url);

      setState(() => isUploading = false);
    } catch (e) {
      setState(() {
        isUploading = false;
        progress = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: uploadFile,
          child: const Text("Upload RC to Supabase"),
        ),
        if (isUploading)
          Column(
            children: [
              LinearProgressIndicator(value: progress / 100),
              Text("${progress.toInt()}%"),
            ],
          ),
      ],
    );
  }
}
