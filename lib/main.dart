import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Hive بطريقة آمنة لوضع الإصدار
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCalcOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // خلفية متدرجة فاخرة
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.5,
                colors: [Color(0xFF1A1A1A), Color(0xFF030303)],
              ),
            ),
          ),
          
          // المحتوى الرئيسي
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
              child: Column(
                children: [
                  // الترويسة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ملاحظاتي',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      _buildGlassButton(Icons.add, () {}),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // شريط البحث
                  GlassContainer(
                    height: 54,
                    width: double.infinity,
                    child: Row(
                      children: const [
                        SizedBox(width: 16),
                        Icon(Icons.search, color: Colors.white54, size: 20),
                        SizedBox(width: 12),
                        Text('ابحث في ملاحظاتك...', style: TextStyle(color: Colors.white54, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // قائمة الملاحظات (تجريبية حالياً)
                  Expanded(
                    child: ListView(
                      children: [
                        _buildNoteCard('خطة المشروع', 'مراجعة التصميم النهائي وإرسال النسخة للعميل. يجب التركيز على الألوان الداكنة والزجاجية.'),
                        _buildNoteCard('أفكار تصميم', 'استخدام تدرجات سوداء مطفية مع حدود فضية رقيقة. الأزرار تعطي إحساس بالبروز واللمعان.'),
                        _buildNoteCard('تسجيل اجتماع', '🎙 مقطع صوتي · 2:14 دقيقة'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // شريط الأدوات السفلي
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: GlassContainer(
              height: 76,
              borderRadius: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToolIcon(Icons.mic_none),
                  _buildToolIcon(Icons.image_outlined),
                  _buildToolIcon(Icons.videocam_outlined),
                  _buildToolIcon(Icons.text_fields),
                  _buildToolIcon(Icons.color_lens_outlined),
                  _buildToolIcon(Icons.calculate_outlined, isActive: _isCalcOpen, onTap: () {
                    setState(() { _isCalcOpen = !_isCalcOpen; });
                  }),
                ],
              ),
            ),
          ),

          // النافذة العائمة للحاسبة
          if (_isCalcOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isCalcOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {}, // لمنع إغلاق النافذة عند الضغط عليها
                      child: _buildCalculator(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 46, width: 46, borderRadius: 16,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildToolIcon(IconData icon, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent),
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildNoteCard(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 13.5, color: Colors.white54, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    return GlassContainer(
      width: 320, height: 480, borderRadius: 32, padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // شاشة الحاسبة
          Container(
            height: 80, alignment: Alignment.bottomLeft,
            child: const Text('1,250', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w300, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          // الأزرار
          Expanded(
            child: GridView.count(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
              children: ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', '.', '='].map((e) {
                bool isEq = e == '=';
                return Container(
                  decoration: BoxDecoration(
                    color: isEq ? Colors.white : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: isEq ? [const BoxShadow(color: Colors.white24, blurRadius: 15)] : [],
                  ),
                  child: Center(
                    child: Text(e, style: TextStyle(
                      fontSize: 22, 
                      color: isEq ? Colors.black : Colors.white, 
                      fontWeight: isEq ? FontWeight.bold : FontWeight.normal
                    )),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}

// ويدجت مخصص لصنع التأثير الزجاجي الفاخر (Glassmorphism)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    Key? key, required this.child, this.height, this.width, this.borderRadius = 18, this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: height, width: width, padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: Colors.white.withOpacity(0.2), offset: const Offset(0, 1), blurRadius: 1),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
