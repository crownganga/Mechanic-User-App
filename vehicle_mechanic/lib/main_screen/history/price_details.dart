import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceDetailsPage extends StatefulWidget {
  final String requestId;
  final bool isEmergency;

  const PriceDetailsPage({
    super.key,
    required this.requestId,
    required this.isEmergency,
  });

  @override
  State<PriceDetailsPage> createState() => _PriceDetailsPageState();
}

class _PriceDetailsPageState extends State<PriceDetailsPage> {
  final supabase = Supabase.instance.client;
  double? existingPrice;

  final TextEditingController priceController = TextEditingController();

  bool saving = false;
  @override
  void initState() {
    super.initState();
    loadPrice();
  }

  Future<void> loadPrice() async {
    final data = await supabase
        .from('mechanic_prices')
        .select('price')
        .eq('request_id', widget.requestId)
        .maybeSingle();

    if (data != null) {
      existingPrice = data['price'];

      priceController.text = data['price'].toString();

      setState(() {});
    }
  }

  Future<void> savePrice() async {
    if (priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter price"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      /// get mechanic id
      final mech = await supabase
          .from('mechanics')
          .select('id')
          .eq('email', supabase.auth.currentUser!.email!)
          .single();

      final mechanicId = mech['id'];

      /// get request details
      final table = widget.isEmergency
          ? 'service_requests'
          : 'service_requests_new';

      final request = await supabase
          .from(table)
          .select('user_id,problem')
          .eq('id', widget.requestId)
          .single();

      /// insert price
      await supabase.from('mechanic_prices').insert({
        'request_id': widget.requestId,

        'mechanic_id': mechanicId,

        'user_id': request['user_id'],

        'problem': request['problem'],

        'price': double.parse(priceController.text),
      });

      /// update request status
      await supabase
          .from(table)
          .update({
            'amount': double.parse(priceController.text),

            'status': 'price_added',
          })
          .eq('id', widget.requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Price saved"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4DAB),

        title: const Text(
          "Price Details",
          style: TextStyle(color: Colors.white),
        ),

        centerTitle: true,

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Service Price",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: priceController,

              readOnly: existingPrice != null,

              keyboardType: TextInputType.number,

              decoration: InputDecoration(
                hintText: "Enter service amount",

                prefixIcon: const Icon(
                  Icons.currency_rupee,
                  color: Color(0xFF0F4DAB),
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,

              height: 55,

              child: ElevatedButton(
                onPressed: saving || existingPrice != null ? null : savePrice,

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4DAB),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            existingPrice != null
                                ? Icons.visibility
                                : Icons.check,
                          ),

                          const SizedBox(width: 8),

                          Text(
                            existingPrice != null
                                ? "Price Saved"
                                : "Confirm Price",

                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
