import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrScreen extends StatefulWidget {
  final ImageSource? initialSource;

  const OcrScreen({super.key, this.initialSource});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String _recognizedText = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectImage(widget.initialSource!);
        }
      });
    }
  }

  // 카메라 또는 갤러리에서 사진 선택
  Future<void> _selectImage(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedImage == null || !mounted) return;

      setState(() {
        _selectedImage = File(pickedImage.path);
        _recognizedText = '';
      });

      await _recognizeText(pickedImage.path);
    } catch (e) {
      _showMessage('사진을 불러오지 못했습니다: $e');
    }
  }

  // Google ML Kit 한국어 OCR
  Future<void> _recognizeText(String imagePath) async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
    });

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final recognizedText = await textRecognizer.processImage(inputImage);

      if (!mounted) return;

      setState(() {
        _recognizedText = recognizedText.text.trim();
      });

      if (_recognizedText.isEmpty) {
        _showMessage(
          '인식된 글자가 없습니다. '
          '선명한 사진으로 다시 시도해 주세요.',
        );
      }
    } catch (e) {
      _showMessage('OCR 인식 중 오류가 발생했습니다: $e');
    } finally {
      await textRecognizer.close();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 결과 초기화
  void _clearResult() {
    if (_isProcessing) return;

    setState(() {
      _selectedImage = null;
      _recognizedText = '';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            onPressed: _isProcessing ? null : _clearResult,
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
                color: Color(0xFF009688),
              ),
              const SizedBox(height: 12),
              const Text(
                '건강검진표를 촬영하거나\n'
                '사진을 선택해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // 사진 선택 버튼
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

              // 선택한 사진 미리보기
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

              // 인식 진행 상태
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      '건강검진표의 글자를 '
                      '인식하고 있습니다...',
                    ),
                  ],
                ),

              // OCR 인식 결과
              if (!_isProcessing && _selectedImage != null) ...[
                const Text(
                  '인식 결과',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    _recognizedText.isEmpty ? '인식된 글자가 없습니다.' : _recognizedText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],

              // 기존 VitalBridge로 결과 전달
              if (!_isProcessing && _recognizedText.isNotEmpty) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, _recognizedText);
                  },
                  child: const Text('인식 결과 사용하기'),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                '※ OCR 인식 결과는 정확하지 않을 수 '
                '있으므로 반드시 확인해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
