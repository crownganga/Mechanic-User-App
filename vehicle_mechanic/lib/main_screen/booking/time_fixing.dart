import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class TimeFixingPage extends StatefulWidget {
  final String requestId;
  final bool isEmergency;

  const TimeFixingPage({
    super.key,
    required this.requestId,
    required this.isEmergency,
  });

  @override
  State<TimeFixingPage> createState() => _TimeFixingPageState();
}

class _TimeFixingPageState extends State<TimeFixingPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? request;

  bool loading = true;
  bool saving = false;

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  @override
  void initState() {
    super.initState();
    loadRequest();
  }

  /// LOAD REQUEST
  Future<void> loadRequest() async {
    try {
      final table = widget.isEmergency
          ? 'service_requests'
          : 'service_requests_new';

      final data = await supabase
          .from(table)
          .select('''
id,
problem,
description,
user_id,
vehicle_id,
status
''')
          .eq('id', widget.requestId)
          .maybeSingle();

      if (data == null) {
        setState(() => loading = false);
        return;
      }

      /// FETCH USER
      Map<String, dynamic>? user;

      if (data['user_id'] != null) {
        user = await supabase
            .from('users_data')
            .select('name,phone')
            .eq('user_id', data['user_id'])
            .maybeSingle();
      }

      /// FETCH VEHICLE
      Map<String, dynamic>? vehicle;

      if (data['vehicle_id'] != null) {
        vehicle = await supabase
            .from('vehicles')
            .select('vehicle_type,brand,model,registration_number')
            .eq('id', data['vehicle_id'])
            .maybeSingle();
      }

      /// MERGE DATA
      data['users_data'] = user;
      data['vehicles'] = vehicle;

      if (!mounted) return;

      setState(() {
        request = data;

        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD ERROR $e");

      setState(() => loading = false);
    }
  }

  /// SUBMIT TIME
  Future<void> submitTime() async {
    if (startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select time"),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() => saving = true);

    try {
      /// mechanic id
      final mech = await supabase
          .from('mechanics')
          .select('id')
          .eq('email', supabase.auth.currentUser!.email!)
          .single();

      String toSql(TimeOfDay t) {
        return "${t.hour.toString().padLeft(2, '0')}:"
            "${t.minute.toString().padLeft(2, '0')}:00";
      }

      /// INSERT FIX SERVICE TIME
      await supabase.from('fix_service_time').insert({
        'status': 'scheduled', // ⭐ ADD THIS

        'request_id': widget.requestId,

        'mechanic_id': mech['id'],

        'user_id': request!['user_id'],

        'vehicle_id': request!['vehicle_id'],

        'problem': request!['problem'],

        'start_time': toSql(startTime!),

        'end_time': toSql(endTime!),

        'work_date': DateTime.now().toIso8601String().split('T').first,
      });

      /// UPDATE REQUEST STATUS
      await supabase
          .from('service_requests_new')
          .update({
            'status': 'time_fixed',
            'mechanic_id': mech['id'], // ⭐ IMPORTANT
          })
          .eq('id', widget.requestId);
      /*   await NotificationService.show(
        title: "Service Scheduled",

        body: "Mechanic fixed service time",
      );*/

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Time fixed successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }

    setState(() => saving = false);
  }

  /// TIME PICKER
  Future<void> pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,

      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        startTime = picked;
      } else {
        endTime = picked;
      }
    });
  }

  /// UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fix Service Time"),

        backgroundColor: const Color(0xFF0F4DAB),

        foregroundColor: Colors.white,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : request == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text("Loading request..."),

                  const SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: loadRequest,

                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : buildContent(),
    );
  }

  /// CONTENT
  Widget buildContent() {
    final vehicle = request!['vehicles'];
    final user = request!['users_data'];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            /// CUSTOMER CARD
            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF0F4DAB)),

                        SizedBox(width: 8),

                        Text(
                          "Customer Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    Text(user?['name'] ?? "-", style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 15),

            /// VEHICLE CARD
            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car, color: Color(0xFF0F4DAB)),

                        SizedBox(width: 8),

                        Text(
                          "Vehicle Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    Text("Type : ${vehicle?['vehicle_type'] ?? "-"}"),

                    Text("Brand : ${vehicle?['brand'] ?? "-"}"),

                    Text("Model : ${vehicle?['model'] ?? "-"}"),

                    Text("Reg No : ${vehicle?['registration_number'] ?? "-"}"),
                  ],
                ),
              ),
            ),

            SizedBox(height: 15),

            /// PROBLEM CARD
            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Icon(Icons.build, color: Color(0xFF0F4DAB)),

                        SizedBox(width: 8),

                        Text(
                          "Service Problem",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    Text(request!['problem'] ?? "-"),

                    if (request!['description'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),

                        child: Text(request!['description']),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            /// TIME CARD
            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),

              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF0F4DAB)),

                        SizedBox(width: 8),

                        Text(
                          "Fix Service Time",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(true),

                            child: Text(
                              startTime == null
                                  ? "Start Time"
                                  : startTime!.format(context),
                            ),
                          ),
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickTime(false),

                            child: Text(
                              endTime == null
                                  ? "End Time"
                                  : endTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 25),

            /// SUBMIT BUTTON
            SizedBox(
              width: double.infinity,

              height: 55,

              child: ElevatedButton(
                onPressed: saving ? null : submitTime,

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4DAB),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),

                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Submit Time",

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
