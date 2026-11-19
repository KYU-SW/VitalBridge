import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const HealthCheckOcrApp());
}

class HealthCheckOcrApp extends StatelessWidget {
  const HealthCheckOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '건강검진 OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7FF9),
        ),
        useMaterial3: true,
      ),
      home: const OcrHomePage(),
    );
  }
}

class OcrHomePage extends StatefulWidget {
  const OcrHomePage({super.key});

  @override
  State<OcrHomePage> createState() => _OcrHomePageState();
}

class _OcrHomePageState extends State<OcrHomePage> {
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String _recognizedText = '';
  bool _isProcessing = false;

  Future<void> _selectImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedImage == null) {
        return;
      }

      setState(() {
        _selectedImage = File(pickedImage.path);
        _recognizedText = '';
      });

      await _recognizeText(pickedImage.path);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지를 불러오지 못했습니다: $error'),
        ),
      );
    }
  }

  Future<void> _recognizeText(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.korean,
    );

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      if (!mounted) return;

      setState(() {
        _recognizedText = recognizedText.text.trim();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _recognizedText = '글자 인식 중 오류가 발생했습니다.\n$error';
      });
    } finally {
      await textRecognizer.close();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _clearResult() {
    setState(() {
      _selectedImage = null;
      _recognizedText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '건강검진표 OCR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _clearResult,
            icon: const Icon(Icons.delete_outline),
            tooltip: '결과 지우기',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 72,
                color: Color(0xFF2D7FF9),
              ),
              const SizedBox(height: 12),
              const Text(
                '건강검진표를 촬영하거나\n사진을 선택해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _selectImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('카메라'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _selectImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('사진 선택'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              if (_selectedImage != null) const SizedBox(height: 24),
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('건강검진표의 글자를 인식하고 있습니다...'),
                  ],
                ),
              if (!_isProcessing && _selectedImage != null) ...[
                const Text(
                  '인식 결과',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD7E2F0),
                    ),
                  ),
                  child: SelectableText(
                    _recognizedText.isEmpty
                        ? '인식된 글자가 없습니다.\n사진을 선명하게 촬영한 뒤 다시 시도해 주세요.'
                        : _recognizedText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}