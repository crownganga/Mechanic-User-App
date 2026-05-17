import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProblemPrizePage extends StatefulWidget {
  final String mechanicId; // ✅ ADD THIS

  const EditProblemPrizePage({super.key, required this.mechanicId});

  @override
  State<EditProblemPrizePage> createState() => _EditProblemPrizePageState();
}

class _EditProblemPrizePageState extends State<EditProblemPrizePage> {
  final supabase = Supabase.instance.client;

  final TextEditingController problemCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  bool saving = false;

  Future<void> saveProblemPrize() async {
    if (problemCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;

    setState(() => saving = true);

    await supabase.from('problem_prize').insert({
      'mechanic_id': widget.mechanicId, // ✅ USE MECHANIC ID
      'problem': problemCtrl.text.trim(),
      'price': double.parse(priceCtrl.text.trim()),
    });

    if (!mounted) return;
    Navigator.pop(context, true); // ✅ RETURN SUCCESS
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Problem & Price"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: problemCtrl,
              decoration: const InputDecoration(
                labelText: "Vehicle Problem",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4DAB),
                ),
                onPressed: saving ? null : saveProblemPrize,
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
