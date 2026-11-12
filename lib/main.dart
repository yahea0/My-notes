import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('notes'); 
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.white,
        fontFamily: 'Tahoma',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
      ),
      // إجبار التطبيق على الاتجاه العربي من اليمين لليسار
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

// ==================== شاشة البداية والترحيب ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.5), radius: 1.2, colors: [Color(0xFF222222), Color(0xFF050505)]),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white24), boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)]),
                child: const Icon(Icons.edit_note, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 30),
              const Text('ملاحظاتي', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              const Text('سجل أفكارك.. تنظم حياتك', style: TextStyle(fontSize: 16, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== الشاشة الرئيسية ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملاحظاتي', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('الكل', Icons.apps),
                _buildCategoryChip('العمل', Icons.work_outline),
                _buildCategoryChip('الدراسة', Icons.school_outlined),
                _buildCategoryChip('شخصي', Icons.person_outline),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('notes').listenable(),
              builder: (context, Box box, _) {
                final Map<dynamic, dynamic> rawNotes = box.toMap();
                final List<MapEntry<dynamic, dynamic>> allNotes = rawNotes.entries.toList();

                final filteredNotes = allNotes.where((entry) {
                  final note = entry.value;
                  if (selectedCategory == 'الكل') return true;
                  return note['category'] == selectedCategory;
                }).toList();

                if (filteredNotes.isEmpty) {
                  return const Center(child: Text('لا توجد ملاحظات هنا...', style: TextStyle(color: Colors.white54, fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index].value;
                    final noteKey = filteredNotes[index].key;
                    return _buildNoteCard(note, noteKey, box);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddNoteScreen())),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.archive_outlined), label: 'الأرشيف'),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'المفضلة'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String title, IconData icon) {
    bool isSelected = selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = title),
      child: Container(
        margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map note, dynamic noteKey, Box box) {
    return InkWell(
      onTap: () {
        // فتح الملاحظة للتعديل
        Navigator.push(context, MaterialPageRoute(builder: (context) => AddNoteScreen(note: note, noteKey: noteKey)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(note['title'] ?? 'بدون عنوان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _showDeleteConfirmation(context, box, noteKey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(note['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.white54, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(note['category'] ?? 'عام', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(note['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(note['time'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // نافذة تأكيد الحذف الأنيقة
  void _showDeleteConfirmation(BuildContext context, Box box, dynamic noteKey) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
          title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                box.delete(noteKey);
                Navigator.pop(context);
              },
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== شاشة إضافة/تعديل ملاحظة ====================
class AddNoteScreen extends StatefulWidget {
  final Map? note;
  final dynamic noteKey;

  const AddNoteScreen({Key? key, this.note, this.noteKey}) : super(key: key);

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String _selectedCategory = 'عام';
  
  bool _isCalcOpen = false;
  String _calcDisplay = '0';
  String _calcExpression = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note != null ? widget.note!['title'] : '');
    _contentController = TextEditingController(text: widget.note != null ? widget.note!['content'] : '');
    _selectedCategory = widget.note != null ? widget.note!['category'] : 'عام';
  }

  void _saveNote() {
    if (_titleController.text.isNotEmpty || _contentController.text.isNotEmpty) {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy/MM/dd').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      if (widget.note == null) {
        // إضافة جديدة
        Hive.box('notes').add({
          'title': _titleController.text,
          'content': _contentController.text,
          'category': _selectedCategory,
          'date': dateStr,
          'time': timeStr,
        });
      } else {
        // تعديل موجودة
        Hive.box('notes').put(widget.noteKey, {
          'title': _titleController.text,
          'content': _contentController.text,
          'category': _selectedCategory,
          'date': widget.note!['date'], // نحتفظ بتاريخ الإنشاء
          'time': widget.note!['time'],
        });
      }
      Navigator.pop(context);
    }
  }

  // الحاسبة الحقيقية
  void _onCalcButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _calcDisplay = '0';
        _calcExpression = '';
      } else if (value == '⌫') {
        if (_calcDisplay.isNotEmpty && _calcDisplay != '0') {
          _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
          if (_calcDisplay.isEmpty) _calcDisplay = '0';
        }
      } else if (value == '=') {
        try {
          // استخدام مكتبة math_expressions لحساب النتيجة
          String exp = _calcDisplay.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
          Parser p = Parser();
          Expression expParsed = p.parse(exp);
          ContextModel cm = ContextModel();
          double eval = expParsed.evaluate(EvaluationType.REAL, cm);
          
          _calcDisplay = eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
        } catch (e) {
          _calcDisplay = 'خطأ';
        }
      } else {
        if (_calcDisplay == '0' && value != '.') {
          _calcDisplay = value;
        } else {
          _calcDisplay += value;
        }
      }
    });
  }

  // إدراج النتيجة في النص
  void _insertResult() {
    if (_calcDisplay != 'خطأ') {
      _contentController.insertText(_calcDisplay);
      setState(() => _isCalcOpen = false);
    }
  }

  // اختيار صورة من المعرض
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // سيتم إضافة منطق حفظ الصورة هنا في التحديث القادم
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اختيار الصورة (سيتم تفعيل الحفظ قريباً)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: _saveNote),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: const InputDecoration(hintText: 'عنوان الملاحظة...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
                    decoration: const InputDecoration(hintText: 'اكتب ملاحظتك هنا...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.image_outlined, color: Colors.white70), onPressed: _pickImage),
                      IconButton(icon: const Icon(Icons.mic_none, color: Colors.white70), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تسجيل الصوت قريباً'))); }),
                      IconButton(icon: const Icon(Icons.color_lens_outlined, color: Colors.white70), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الألوان قريباً'))); }),
                      IconButton(
                        icon: Icon(Icons.calculate_outlined, color: _isCalcOpen ? Colors.white : Colors.white70),
                        onPressed: () => setState(() => _isCalcOpen = !_isCalcOpen),
                      ),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: const Color(0xFF1E1E1E),
                        underline: Container(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        style: const TextStyle(color: Colors.white),
                        items: ['عام', 'العمل', 'الدراسة', 'شخصي'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // الحاسبة العائمة
          if (_isCalcOpen)
            Positioned(
              bottom: 80, left: 20, right: 20,
              child: GlassContainer(
                borderRadius: 24, padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.all(12),
                      child: Text(_calcDisplay, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true, crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
                      children: ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', '.', '='].map((e) {
                        bool isEq = e == '=';
                        return InkWell(
                          onTap: () => _onCalcButtonPressed(e),
                          child: Container(
                            decoration: BoxDecoration(color: isEq ? Colors.white : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                            child: Center(child: Text(e, style: TextStyle(fontSize: 20, color: isEq ? Colors.black : Colors.white))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // زر إدراج النتيجة
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _insertResult,
                        icon: const Icon(Icons.input, size: 18),
                        label: const Text('إدراج النتيجة في النص', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== ويدجت الزجاج ====================
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({Key? key, required this.child, this.height, this.width, this.borderRadius = 18, this.padding}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: height, width: width, padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
