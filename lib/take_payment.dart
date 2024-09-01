import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    await Permission.storage.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _purposeController,
              decoration: InputDecoration(labelText: 'Purpose'),
            ),
            SizedBox(height: 20),
            IconTextButton(
              icon: Icons.qr_code,
              text: 'Generate QR Code',
              onPressed: () {
                generateQRCode(context);
              },
            ),
            SizedBox(height: 20),
            IconTextButton(
              icon: Icons.link,
              text: 'Generate Payment Link',
              onPressed: () {
                // Add your payment link generation logic here
                print('Generate Payment Link button pressed');
              },
            ),
          ],
        ),
      ),
    );
  }

  void generateQRCode(BuildContext context) async {
    const url = 'https://api.razorpay.com/v1/payments/qr_codes';
    const username = 'rzp_live_ymUGpkKEgzMtUI';
    const password = '9C0ZR6Leq95VeoRdDXuWQ39f';
    final credentials = base64Encode(utf8.encode('$username:$password'));
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $credentials',
    };
    final amount = int.parse(_amountController.text) * 100; // converting to paise
    final body = jsonEncode({
      "type": "upi_qr",
      "name": "Store Front Display",
      "usage": "single_use",
      "fixed_amount": true,
      "payment_amount": amount,
      "description": _descriptionController.text,
      "customer_id": "cust_Oe2XGOHUbuQ5Cd",
      "close_by": 1722690710,
      "notes": {"purpose": _purposeController.text},
    });

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final imageUrl = data['image_url'];
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('QR Code Details'),
            content: Image.network(imageUrl),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
              TextButton(
                onPressed: () => downloadImage(context, imageUrl),
                child: Text('Download'),
              ),
            ],
          ),
        );
      } else {
        showErrorDialog(context, 'Failed to generate QR code: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Error: $e');
    }
  }

  Future<void> downloadImage(BuildContext context, String imageUrl) async {
    final Uri _url = Uri.parse(imageUrl);

    if (await canLaunchUrl(_url)) {
      await launchUrl(_url);
    } else {
      throw 'Could not launch $_url';
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

class IconTextButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  IconTextButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
