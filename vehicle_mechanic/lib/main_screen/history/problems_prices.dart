import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_problem_prize.dart';

class ProblemPrizePage extends StatefulWidget {
  const ProblemPrizePage({super.key});

  @override
  State<ProblemPrizePage> createState() => _ProblemPrizePageState();
}

class _ProblemPrizePageState extends State<ProblemPrizePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> problemPrizeList = [];

  String? mechanicId;

  @override
  void initState() {
    super.initState();
    loadMechanicAndProblems();
  }

  // 🔹 LOAD mechanic_id + problem_prize
  Future<void> loadMechanicAndProblems() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final mech = await supabase
          .from('mechanics')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      setState(() {
        mechanicId = mech?['id']; // ✅ VERY IMPORTANT
      });
      debugPrint("USER ID => ${supabase.auth.currentUser?.id}");
      debugPrint("MECHANIC ROW => $mech");

      final res = await supabase
          .from('problem_prize')
          .select()
          .eq('mechanic_id', mechanicId!)
          .order('created_at');

      setState(() {
        problemPrizeList = List<Map<String, dynamic>>.from(res);
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ LOAD ERROR: $e");
      setState(() => loading = false);
    }
  }

  Future<void> deleteProblem(String problemId) async {
    try {
      await supabase.from('problem_prize').delete().eq('id', problemId);

      // Refresh list
      loadMechanicAndProblems();
    } catch (e) {
      debugPrint("❌ DELETE ERROR: $e");
    }
  }

  void confirmDelete(BuildContext context, String problemId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Problem"),
        content: const Text("Are you sure you want to delete this problem?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteProblem(problemId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Problem & Price"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : problemPrizeList.isEmpty
          ? const Center(
              child: Text("No Problems Added", style: TextStyle(fontSize: 18)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: problemPrizeList.length,
              itemBuilder: (context, index) {
                final item = problemPrizeList[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      item['problem'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("₹ ${item['price']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        confirmDelete(context, item['id']);
                      },
                    ),
                  ),
                );
              },
            ),

      // ✅ ADD / EDIT
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F4DAB),
        onPressed: () async {
          if (mechanicId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Mechanic account not linked")),
            );
            return;
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProblemPrizePage(mechanicId: mechanicId!),
            ),
          );

          if (result == true) {
            loadMechanicAndProblems();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
