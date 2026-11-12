import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'; // إضافة هذا الاستيراد

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Hive بطريقة آمنة لوضع الإصدار
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  // Hive.initFlutter(); // يمكنك استخدام هذا السطر بدلاً من السطرين السابقين إذا أردت، لكن الطريقة أعلاه أكثر أماناً

  runApp(const MyNotesApp());
}

class MyNotesApp extends StatelessWidget {
  const MyNotesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luxury Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030303),
        fontFamily: 'Tahoma',
      ),
      home: const HomeScreen(),
    );
  }
}

// ... (باقي الكود كما هو، لا حاجة لتغييره)
