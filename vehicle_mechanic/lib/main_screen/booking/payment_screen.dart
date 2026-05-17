import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final String requestId;
  final bool isEmergency;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.isEmergency,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final supabase = Supabase.instance.client;
  bool paying = false;

  Future<void> completePayment() async {
    setState(() => paying = true);

    await supabase
        .from(widget.isEmergency ? 'service_requests' : 'service_requests_new')
        .update({'status': 'paid'})
        .eq('id', widget.requestId);

    if (!mounted) return;

    Navigator.pop(context, true); // ✅ return success
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: const Color(0xFF0F4DAB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: paying
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: completePayment,
                child: const Text("Confirm Payment"),
              ),
      ),
    );
  }
}
