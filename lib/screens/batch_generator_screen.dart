import 'package:flutter/material.dart';

class BatchGeneratorScreen extends StatefulWidget {
  const BatchGeneratorScreen({super.key});

  @override
  State<BatchGeneratorScreen> createState() => _BatchGeneratorScreenState();
}

class _BatchGeneratorScreenState extends State<BatchGeneratorScreen> {
  bool _isProcessing = false;

  void _pickFilesAndProcess() async {
    // We will implement file picking logic later
    setState(() {
      _isProcessing = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isProcessing = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not fully implemented yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Generation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 24),
              const Text(
                'Upload a CSV or Excel (.xlsx) file.\nThe first column will be used to generate Bulk QR codes which will be saved in a ZIP file.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              _isProcessing 
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _pickFilesAndProcess,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
