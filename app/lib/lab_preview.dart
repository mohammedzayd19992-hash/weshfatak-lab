import 'package:flutter/material.dart';

import 'brand.dart';

class LabPreviewApp extends StatelessWidget {
  const LabPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WeshFatak — Lab Preview',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: Scaffold(
      appBar: AppBar(title: const Text('WeshFatak · وش فاتك')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'IN DEVELOPMENT · LAB PREVIEW',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          SizedBox(height: 16),
          Text(
            'Education news, in one place',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'This offline preview uses fictional examples. It does not connect to the live service, collect personal information, or allow account creation.',
          ),
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FICTIONAL EXAMPLE · ACADEMIC'),
                  SizedBox(height: 12),
                  Text(
                    'Explore the new semester guide',
                    style: TextStyle(fontSize: 22),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'An example education announcement illustrates the type of story WeshFatak brings together. This is not an official announcement.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Planned / development features: audience and category filters, article media, comments, community summaries and saved news alerts.',
          ),
          SizedBox(height: 16),
          Text(
            'Full application source is included for code review. A separate disposable backend is required to test connected features. This project is not production-ready or an official education service.',
          ),
        ],
      ),
    ),
  );
}
