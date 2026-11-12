import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:math_expressions/math_expressions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:photo_view/photo_view.dart'; // مكتبة عرض الصور

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

// ==================== شاشة البداية ====================
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedCategory = 'الكل';
  int _currentIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu), 
          onPressed: () => _scaffoldKey.currentState?.openDrawer()
        ),
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(hintText: 'ابحث عن ملاحظة...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
              onChanged: (val) => setState(() => _searchQuery = val),
            )
          : Text(_getTitleByIndex(_currentIndex), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_currentIndex != 3)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search), 
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false; _searchQuery = ''; _searchController.clear();
                  } else { _isSearching = true; }
                });
              }
            ),
        ],
      ),
      body: _currentIndex == 3 
          ? _buildSettingsScreen()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isSearching)
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
                        final title = note['title'] ?? '';
                        final content = note['content'] ?? '';
                        final category = note['category'] ?? 'عام';
                        final isArchived = note['isArchived'] ?? false;
                        final isFavorite = note['isFavorite'] ?? false;

                        bool matchesSearch = title.contains(_searchQuery) || content.contains(_searchQuery);
                        bool matchesTab = false;
                        if (_currentIndex == 0) matchesTab = !isArchived; 
                        if (_currentIndex == 1) matchesTab = isArchived; 
                        if (_currentIndex == 2) matchesTab = isFavorite && !isArchived;
                        bool matchesCategory = selectedCategory == 'الكل' || category == selectedCategory;

                        return matchesSearch && matchesTab && matchesCategory;
                      }).toList();

                      filteredNotes.sort((a, b) {
                        bool aPinned = a.value['isPinned'] ?? false;
                        bool bPinned = b.value['isPinned'] ?? false;
                        if (aPinned && !bPinned) return -1;
                        if (!aPinned && bPinned) return 1;
                        return 0;
                      });

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
      floatingActionButton: _currentIndex == 3 ? null : FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddNoteScreen())),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() { _currentIndex = index; _isSearching = false; });
        },
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

  String _getTitleByIndex(int index) {
    switch (index) {
      case 0: return 'ملاحظاتي';
      case 1: return 'الأرشيف';
      case 2: return 'المفضلة';
      case 3: return 'الإعدادات';
      default: return 'ملاحظاتي';
    }
  }

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('المظهر', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('الوضع الداكن', style: TextStyle(color: Colors.white)),
          value: true,
          onChanged: (val) {},
          activeColor: Colors.white,
          tileColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        const SizedBox(height: 20),
        const Text('البيانات', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: const Text('مسح جميع الملاحظات', style: TextStyle(color: Colors.redAccent)),
          tileColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF161616),
                title: const Text('تأكيد', style: TextStyle(color: Colors.white)),
                content: const Text('هل تريد مسح جميع الملاحظات نهائياً؟', style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                  TextButton(
                    onPressed: () {
                      Hive.box('notes').clear();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح جميع الملاحظات')));
                    }, 
                    child: const Text('مسح', style: TextStyle(color: Colors.redAccent))
                  ),
                ],
              )
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('حول', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.white),
          title: const Text('حول التطبيق', style: TextStyle(color: Colors.white)),
          subtitle: const Text('الإصدار 1.0.0', style: TextStyle(color: Colors.white38)),
          tileColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () {
            showAboutDialog(context: context, applicationName: 'ملاحظاتي', applicationVersion: '1.0.0');
          },
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF0F0F0F), border: Border(left: BorderSide(color: Colors.white12))),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(radius: 40, backgroundColor: Color(0xFF222222), child: Icon(Icons.person, size: 50, color: Colors.white54)),
                  const SizedBox(height: 10),
                  const Text('ملاحظاتي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('نسخة احترافية', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.home, 'الرئيسية', () { Navigator.pop(context); setState(() => _currentIndex = 0); }),
            _buildDrawerItem(Icons.star_border, 'المفضلة', () { Navigator.pop(context); setState(() => _currentIndex = 2); }),
            _buildDrawerItem(Icons.archive_outlined, 'الأرشيف', () { Navigator.pop(context); setState(() => _currentIndex = 1); }),
            _buildDrawerItem(Icons.settings_outlined, 'الإعدادات', () { Navigator.pop(context); setState(() => _currentIndex = 3); }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: Colors.white70), title: Text(title, style: const TextStyle(color: Colors.white)), onTap: onTap);
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
    bool isFav = note['isFavorite'] ?? false;
    bool isPinned = note['isPinned'] ?? false;
    Color textColor = note['textColor'] != null ? Color(note['textColor']) : Colors.white;
    String fontFam = note['fontFamily'] ?? 'Tahoma';
    double fontSize = note['fontSize'] ?? 18.0;
    String? imagePath = note['imagePath'];
    String? audioPath = note['audioPath'];
    String? audioName = note['audioName']; // اسم التسجيل

    TextStyle titleStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor);
    if (fontFam == 'Cairo') titleStyle = GoogleFonts.cairo(textStyle: titleStyle);
    if (fontFam == 'Amiri') titleStyle = GoogleFonts.amiri(textStyle: titleStyle);
    if (fontFam == 'Tajawal') titleStyle = GoogleFonts.tajawal(textStyle: titleStyle);
    if (fontFam == 'Almarai') titleStyle = GoogleFonts.almarai(textStyle: titleStyle);
    if (fontFam == 'Noto Naskh Arabic') titleStyle = GoogleFonts.notoNaskhArabic(textStyle: titleStyle);
    if (fontFam == 'Reem Kufi') titleStyle = GoogleFonts.reemKufi(textStyle: titleStyle);
    if (fontFam == 'El Messiri') titleStyle = GoogleFonts.elMessiri(textStyle: titleStyle);
    if (fontFam == 'Markazi Text') titleStyle = GoogleFonts.markaziText(textStyle: titleStyle);
    if (fontFam == 'Changa') titleStyle = GoogleFonts.changa(textStyle: titleStyle);
    if (fontFam == 'Mada') titleStyle = GoogleFonts.mada(textStyle: titleStyle);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddNoteScreen(note: note, noteKey: noteKey))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPinned ? Colors.white54 : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(note['title'] ?? 'بدون عنوان', style: titleStyle)),
                Row(
                  children: [
                    // إزالة زر التثبيت من الخارج بناءً على طلبك
                    IconButton(icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.white38, size: 22), onPressed: () {
                      Map updatedNote = Map.from(note);
                      updatedNote['isFavorite'] = !isFav;
                      box.put(noteKey, updatedNote);
                    }),
                    IconButton(icon: const Icon(Icons.archive_outlined, color: Colors.white38, size: 20), onPressed: () {
                      Map updatedNote = Map.from(note);
                      updatedNote['isArchived'] = true;
                      box.put(noteKey, updatedNote);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الأرشفة')));
                    }),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _showDeleteConfirmation(context, box, noteKey)),
                  ],
                ),
              ],
            ),
            if (imagePath != null) 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(imagePath), height: 100, width: double.infinity, fit: BoxFit.cover)),
              ),
            if (audioPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(audioName ?? 'ملف صوتي مرفق', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(note['content'] ?? '', style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7), height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                    Row(children: [const Icon(Icons.calendar_today, size: 12, color: Colors.white38), const SizedBox(width: 4), Text(note['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white38))]),
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.access_time, size: 12, color: Colors.white38), const SizedBox(width: 4), Text(note['time'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white38))]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Box box, dynamic noteKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذه الملاحظة؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () { box.delete(noteKey); Navigator.pop(context); }, child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
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
  
  // التنسيق
  Color _titleColor = Colors.white;
  Color _contentColor = Colors.white;
  String _fontFamily = 'Tahoma';
  double _titleFontSize = 22.0;
  double _contentFontSize = 16.0;
  bool _styleForTitle = true; // true للعنوان، false للنص

  // الوسائط
  String? _imagePath;
  String? _audioPath;
  String? _audioName;

  // الحاسبة
  bool _isCalcOpen = false;
  String _calcDisplay = '0';

  // الصوت
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // التثبيت
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note != null ? widget.note!['title'] : '');
    _contentController = TextEditingController(text: widget.note != null ? widget.note!['content'] : '');
    _selectedCategory = widget.note != null ? widget.note!['category'] : 'عام';
    
    if (widget.note != null) {
      _titleColor = widget.note!['textColor'] != null ? Color(widget.note!['textColor']) : Colors.white;
      _contentColor = widget.note!['contentColor'] != null ? Color(widget.note!['contentColor']) : Colors.white;
      _fontFamily = widget.note!['fontFamily'] ?? 'Tahoma';
      _titleFontSize = widget.note!['titleFontSize'] ?? 22.0;
      _contentFontSize = widget.note!['contentFontSize'] ?? 16.0;
      _imagePath = widget.note!['imagePath'];
      _audioPath = widget.note!['audioPath'];
      _audioName = widget.note!['audioName'];
      _isPinned = widget.note!['isPinned'] ?? false;
    }
  }

  void _saveNote() async {
    if (_titleController.text.isNotEmpty || _contentController.text.isNotEmpty) {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy/MM/dd').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      Map<String, dynamic> noteData = {
        'title': _titleController.text,
        'content': _contentController.text,
        'category': _selectedCategory,
        'date': widget.note != null ? widget.note!['date'] : dateStr,
        'time': widget.note != null ? widget.note!['time'] : timeStr,
        'isFavorite': widget.note != null ? widget.note!['isFavorite'] ?? false : false,
        'isArchived': widget.note != null ? widget.note!['isArchived'] ?? false : false,
        'isPinned': _isPinned,
        'textColor': _titleColor.value,
        'contentColor': _contentColor.value,
        'fontFamily': _fontFamily,
        'titleFontSize': _titleFontSize,
        'contentFontSize': _contentFontSize,
        'imagePath': _imagePath,
        'audioPath': _audioPath,
        'audioName': _audioName,
      };

      if (widget.note == null) {
        Hive.box('notes').add(noteData);
      } else {
        Hive.box('notes').put(widget.noteKey, noteData);
      }
      Navigator.pop(context);
    }
  }

  // اختيار لون
  void _pickColor() {
    Color currentColor = _styleForTitle ? _titleColor : _contentColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: Text(_styleForTitle ? 'اختر لون العنوان' : 'اختر لون النص', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (_styleForTitle) { _titleColor = color; } else { _contentColor = color; }
              });
            },
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تم', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // اختيار الخط
  void _pickFont() {
    // قائمة بأشهر الخطوط العربية
    final List<Map<String, String>> fonts = [
      {'id': 'Tahoma', 'name': 'افتراضي'},
      {'id': 'Cairo', 'name': 'القاهرة'},
      {'id': 'Tajawal', 'name': 'تجوال'},
      {'id': 'Amiri', 'name': 'أميري'},
      {'id': 'Almarai', 'name': 'المراعي'},
      {'id': 'Noto Naskh Arabic', 'name': 'نوتو نسخ'},
      {'id': 'Reem Kufi', 'name': 'ريم كوفي'},
      {'id': 'El Messiri', 'name': 'المسيري'},
      {'id': 'Markazi Text', 'name': 'مركزي'},
      {'id': 'Changa', 'name': 'تشانغا'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder( // استخدام StatefulBuilder لتحديث الشريط فوراً
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختر الخط وحجمه', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  
                  // خيار: هل التغيير للعنوان أم النص؟
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('العنوان'),
                        selected: _styleForTitle,
                        onSelected: (val) => setModalState(() => _styleForTitle = true),
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(color: _styleForTitle ? Colors.black : Colors.white),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('النص'),
                        selected: !_styleForTitle,
                        onSelected: (val) => setModalState(() => _styleForTitle = false),
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(color: !_styleForTitle ? Colors.black : Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // قائمة الخطوط
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fonts.length,
                      itemBuilder: (context, index) {
                        final f = fonts[index];
                        bool isSelected = _fontFamily == f['id'];
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => _fontFamily = f['id']!);
                            setState(() {}); // تحديث الشاشة الرئيسية أيضاً
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(f['name']!, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontFamily: f['id'] == 'Tahoma' ? null : f['id'])),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Text('حجم الخط (${_styleForTitle ? _titleFontSize.toInt() : _contentFontSize.toInt()})', style: const TextStyle(color: Colors.white)),
                  
                  // شريط التمرير
                  Slider(
                    value: _styleForTitle ? _titleFontSize : _contentFontSize,
                    min: 12,
                    max: 40,
                    activeColor: Colors.white,
                    onChanged: (val) {
                      setModalState(() {
                        if (_styleForTitle) { _titleFontSize = val; } else { _contentFontSize = val; }
                      });
                      setState(() {}); // تحديث الشاشة الرئيسية
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // اختيار صورة
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  // عرض الصورة بالحجم الكامل
  void _viewFullImage() {
    if (_imagePath == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(File(_imagePath!)),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تسجيل صوت
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
        _audioName = 'تسجيل جديد'; // اسم افتراضي
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصوت')));
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  // تشغيل الصوت
  Future<void> _playAudio() async {
    if (_audioPath != null) {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(_audioPath!));
    }
  }

  // تغيير اسم التسجيل
  void _renameAudio() {
    TextEditingController _controller = TextEditingController(text: _audioName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('اسم التسجيل', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'أدخل اسماً...', hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              setState(() => _audioName = _controller.text);
              Navigator.pop(context);
            }, 
            child: const Text('حفظ', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  // الحاسبة
  void _onCalcButtonPressed(String value) {
    setState(() {
      if (value == 'C') { _calcDisplay = '0'; } 
      else if (value == '⌫') {
        if (_calcDisplay.isNotEmpty && _calcDisplay != '0') {
          _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
          if (_calcDisplay.isEmpty) _calcDisplay = '0';
        }
      } else if (value == '=') {
        try {
          String exp = _calcDisplay.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
          Parser p = Parser();
          Expression expParsed = p.parse(exp);
          ContextModel cm = ContextModel();
          double eval = expParsed.evaluate(EvaluationType.REAL, cm);
          _calcDisplay = eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
        } catch (e) { _calcDisplay = 'خطأ'; }
      } else {
        if (_calcDisplay == '0' && value != '.') { _calcDisplay = value; } 
        else { _calcDisplay += value; }
      }
    });
  }

  void _insertResult() {
    if (_calcDisplay != 'خطأ') {
      final text = _contentController.text;
      final selection = _contentController.selection;
      if (selection.start == -1) {
        _contentController.text = text + _calcDisplay;
      } else {
        final newText = text.replaceRange(selection.start, selection.end, _calcDisplay);
        _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start + _calcDisplay.length));
      }
      setState(() => _isCalcOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    TextStyle titleStyle = TextStyle(fontSize: _titleFontSize, fontWeight: FontWeight.bold, color: _titleColor);
    TextStyle contentStyle = TextStyle(fontSize: _contentFontSize, color: _contentColor.withOpacity(0.8), height: 1.6);

    if (_fontFamily == 'Cairo') { titleStyle = GoogleFonts.cairo(textStyle: titleStyle); contentStyle = GoogleFonts.cairo(textStyle: contentStyle); }
    if (_fontFamily == 'Amiri') { titleStyle = GoogleFonts.amiri(textStyle: titleStyle); contentStyle = GoogleFonts.amiri(textStyle: contentStyle); }
    if (_fontFamily == 'Tajawal') { titleStyle = GoogleFonts.tajawal(textStyle: titleStyle); contentStyle = GoogleFonts.tajawal(textStyle: contentStyle); }
    if (_fontFamily == 'Almarai') { titleStyle = GoogleFonts.almarai(textStyle: titleStyle); contentStyle = GoogleFonts.almarai(textStyle: contentStyle); }
    if (_fontFamily == 'Noto Naskh Arabic') { titleStyle = GoogleFonts.notoNaskhArabic(textStyle: titleStyle); contentStyle = GoogleFonts.notoNaskhArabic(textStyle: contentStyle); }
    if (_fontFamily == 'Reem Kufi') { titleStyle = GoogleFonts.reemKufi(textStyle: titleStyle); contentStyle = GoogleFonts.reemKufi(textStyle: contentStyle); }
    if (_fontFamily == 'El Messiri') { titleStyle = GoogleFonts.elMessiri(textStyle: titleStyle); contentStyle = GoogleFonts.elMessiri(textStyle: contentStyle); }
    if (_fontFamily == 'Markazi Text') { titleStyle = GoogleFonts.markaziText(textStyle: titleStyle); contentStyle = GoogleFonts.markaziText(textStyle: contentStyle); }
    if (_fontFamily == 'Changa') { titleStyle = GoogleFonts.changa(textStyle: titleStyle); contentStyle = GoogleFonts.changa(textStyle: contentStyle); }

    return Scaffold(
      // منع الكيبورد من تغطية المحتوى
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
        actions: [
          // زر التثبيت الجديد بجانب علامة الصح
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: _isPinned ? Colors.amber : Colors.white),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: _saveNote),
        ],
      ),
      body: Stack(
        children: [
          // تغليف المحتوى بـ SingleChildScrollView لمنع اختفاء النص
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: titleStyle,
                  decoration: const InputDecoration(hintText: 'عنوان الملاحظة...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                ),
                const Divider(color: Colors.white12),
                
                // عرض الصورة المرفقة
                if (_imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Stack(
                      children: [
                        // جعل الصورة قابلة للضغط لعرضها بالكامل
                        GestureDetector(
                          onTap: _viewFullImage,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12), 
                            child: Image.file(
                              File(_imagePath!), 
                              height: 150, 
                              width: double.infinity, 
                              fit: BoxFit.cover // تغطية المساحة بالكامل
                            )
                          ),
                        ),
                        Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _imagePath = null))),
                      ],
                    ),
                  ),
                
                // عرض الصوت المرفق
                if (_audioPath != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.play_circle, color: Colors.green, size: 30), onPressed: _playAudio),
                        Expanded(child: Text(_audioName ?? 'تسجيل صوتي', style: const TextStyle(color: Colors.white70))),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20), onPressed: _renameAudio),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => setState(() => _audioPath = null)),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),
                // حقل النص
                TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: contentStyle,
                  decoration: const InputDecoration(hintText: 'اكتب ملاحظتك هنا...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الحاسبة', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        GestureDetector(
                          onTap: () => setState(() => _isCalcOpen = false),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
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
      // شريط الأدوات السفلي
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12)), color: Color(0xFF0A0A0A)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.image_outlined, color: Colors.white70), onPressed: _pickImage),
              // تغيير شكل زر التسجيل
              IconButton(
                icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_none, color: _isRecording ? Colors.red : Colors.white70), 
                onPressed: _toggleRecording
              ),
              IconButton(icon: const Icon(Icons.color_lens_outlined, color: Colors.white70), onPressed: _pickColor),
              IconButton(icon: const Icon(Icons.text_fields, color: Colors.white70), onPressed: _pickFont),
              IconButton(icon: Icon(Icons.calculate_outlined, color: _isCalcOpen ? Colors.white : Colors.white70), onPressed: () => setState(() => _isCalcOpen = !_isCalcOpen)),
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
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
