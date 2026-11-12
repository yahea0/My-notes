import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // ضروري لاستخدام Int32List
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:math_expressions/math_expressions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

// استيراد مكتبات الإشعارات
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// متغير عام للتحكم بالإشعارات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة قاعدة البيانات
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('notes'); 

  // تهيئة الإشعارات والمنطقة الزمنية
  await _initNotifications();

  runApp(const MyNotesApp());
}

// دالة تهيئة الإشعارات
Future<void> _initNotifications() async {
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // يمكن إضافة منطق عند الضغط على الإشعار هنا
    },
  );

  // طلب إذن الإشعارات والمنبهات
  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();
    await androidImplementation.requestExactAlarmsPermission();
  }
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
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white.withOpacity(0.4),
          selectionHandleColor: Colors.white,
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
    
    Color titleColor = note['textColor'] != null ? Color(note['textColor']) : Colors.white;
    Color contentColor = note['contentColor'] != null ? Color(note['contentColor']) : Colors.white;
    String fontFam = note['fontFamily'] ?? 'Tahoma';
    double titleSize = note['titleFontSize'] ?? 18.0;
    double contentSize = note['contentFontSize'] ?? 14.0;
    
    List<dynamic> imagePaths = note['imagePaths'] ?? [];
    List<dynamic> audioRecords = note['audioRecords'] ?? [];

    TextStyle titleStyle = TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: titleColor);
    TextStyle contentStyle = TextStyle(fontSize: contentSize, color: contentColor.withOpacity(0.8), height: 1.5);

    void applyFont(String fontId) {
      if (fontId == 'Cairo') { titleStyle = GoogleFonts.cairo(textStyle: titleStyle); contentStyle = GoogleFonts.cairo(textStyle: contentStyle); }
      if (fontId == 'Amiri') { titleStyle = GoogleFonts.amiri(textStyle: titleStyle); contentStyle = GoogleFonts.amiri(textStyle: contentStyle); }
      if (fontId == 'Tajawal') { titleStyle = GoogleFonts.tajawal(textStyle: titleStyle); contentStyle = GoogleFonts.tajawal(textStyle: contentStyle); }
      if (fontId == 'Almarai') { titleStyle = GoogleFonts.almarai(textStyle: titleStyle); contentStyle = GoogleFonts.almarai(textStyle: contentStyle); }
      if (fontId == 'Noto Naskh Arabic') { titleStyle = GoogleFonts.notoNaskhArabic(textStyle: titleStyle); contentStyle = GoogleFonts.notoNaskhArabic(textStyle: contentStyle); }
      if (fontId == 'Reem Kufi') { titleStyle = GoogleFonts.reemKufi(textStyle: titleStyle); contentStyle = GoogleFonts.reemKufi(textStyle: contentStyle); }
      if (fontId == 'El Messiri') { titleStyle = GoogleFonts.elMessiri(textStyle: titleStyle); contentStyle = GoogleFonts.elMessiri(textStyle: contentStyle); }
      if (fontId == 'Markazi Text') { titleStyle = GoogleFonts.markaziText(textStyle: titleStyle); contentStyle = GoogleFonts.markaziText(textStyle: contentStyle); }
      if (fontId == 'Changa') { titleStyle = GoogleFonts.changa(textStyle: titleStyle); contentStyle = GoogleFonts.changa(textStyle: contentStyle); }
      if (fontId == 'Aref Ruqaa') { titleStyle = GoogleFonts.arefRuqaa(textStyle: titleStyle); contentStyle = GoogleFonts.arefRuqaa(textStyle: contentStyle); }
      if (fontId == 'Lateef') { titleStyle = GoogleFonts.lateef(textStyle: titleStyle); contentStyle = GoogleFonts.lateef(textStyle: contentStyle); }
      if (fontId == 'Scheherazade New') { titleStyle = GoogleFonts.scheherazadeNew(textStyle: titleStyle); contentStyle = GoogleFonts.scheherazadeNew(textStyle: contentStyle); }
    }
    
    applyFont(fontFam);

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
            if (imagePaths.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(imagePaths[0]), height: 100, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            if (audioRecords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 4),
                    Text('${audioRecords.length} تسجيل صوتي', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              note['content'] ?? '', 
              style: contentStyle, 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis
            ),
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
  final ScrollController _contentScrollController = ScrollController();
  String _selectedCategory = 'عام';
  
  Color _titleColor = Colors.white;
  Color _contentColor = Colors.white;
  String _fontFamily = 'Tahoma';
  double _titleFontSize = 22.0;
  double _contentFontSize = 16.0;
  bool _styleForTitle = true;

  List<String> _imagePaths = [];
  List<Map<String, String>> _audioRecords = [];

  String _calcDisplay = '0';

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentlyPlayingPath;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      _imagePaths = List<String>.from(widget.note!['imagePaths'] ?? []);
      _audioRecords = List<Map<String, String>>.from(
        (widget.note!['audioRecords'] ?? []).map((x) => Map<String, String>.from(x))
      );
      _isPinned = widget.note!['isPinned'] ?? false;
    }

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _currentlyPlayingPath = null);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _contentScrollController.dispose();
    super.dispose();
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
        'imagePaths': _imagePaths,
        'audioRecords': _audioRecords,
      };

      if (widget.note == null) {
        Hive.box('notes').add(noteData);
      } else {
        Hive.box('notes').put(widget.noteKey, noteData);
      }
      Navigator.pop(context);
    }
  }

  void _duplicateNote() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy/MM/dd').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    Map<String, dynamic> newNoteData = {
      'title': 'نسخة من ${_titleController.text}',
      'content': _contentController.text,
      'category': _selectedCategory,
      'date': dateStr,
      'time': timeStr,
      'isFavorite': false,
      'isArchived': false,
      'isPinned': false,
      'textColor': _titleColor.value,
      'contentColor': _contentColor.value,
      'fontFamily': _fontFamily,
      'titleFontSize': _titleFontSize,
      'contentFontSize': _contentFontSize,
      'imagePaths': List<String>.from(_imagePaths),
      'audioRecords': _audioRecords.map((e) => Map<String, String>.from(e)).toList(),
    };

    Hive.box('notes').add(newNoteData);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء نسخة من الملاحظة')));
  }

  // دالة التذكير المعدلة (منبه مستمر)
  void _setReminder() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF161616),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      bool canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
      
      if (!canSchedule) {
        await androidPlugin?.requestExactAlarmsPermission();
        canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
        if (!canSchedule) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يجب السماح بإذن المنبهات الدقيقة (Exact Alarms) لعمل التذكير.')),
            );
          }
          return;
        }
      }

      // طلب إذن الشاشة الكاملة (Full Screen Intent) لأندرويد 14+
      await androidPlugin?.requestFullScreenIntentPermission();

      final now = DateTime.now();
      final scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      
      final finalDate = scheduledDate.isBefore(now) 
          ? scheduledDate.add(const Duration(days: 1)) 
          : scheduledDate;

      // إعداد المنبه المستمر
      await flutterLocalNotificationsPlugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        _titleController.text.isEmpty ? 'تذكير بملاحظة' : _titleController.text,
        _contentController.text.isEmpty ? 'لديك تذكير في هذا الوقت' : _contentController.text,
        tz.TZDateTime.from(finalDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_alarm_channel_v1', // معرف قناة جديد للمنبهات المستمرة
            'المنبهات المستمرة',
            channelDescription: 'منبهات لا تتوقف حتى يتم إيقافها',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm, // تصنيف كمنبه
            fullScreenIntent: true, // إظهار على شاشة القفل
            ongoing: true, // منع الإغلاق التلقائي
            autoCancel: false, // لا يختفي عند الضغط
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4 (الرنين المستمر)
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم ضبط المنبه في ${time.format(context)}')),
        );
      }
    }
  }

  void _searchInNote() {
    TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('البحث داخل الملاحظة', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'أدخل الكلمة للبحث...', 
            hintStyle: TextStyle(color: Colors.white30)
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              String query = searchController.text;
              if (query.isNotEmpty) {
                int startIndex = _contentController.text.indexOf(query);
                if (startIndex != -1) {
                  _contentController.selection = TextSelection(
                    baseOffset: startIndex,
                    extentOffset: startIndex + query.length,
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      _contentController.selection = TextSelection.collapsed(
                        offset: _contentController.selection.end,
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على النص.')));
                }
              }
              Navigator.pop(context);
            }, 
            child: const Text('بحث', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

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

  void _pickFont() {
    final List<Map<String, String>> fonts = [
      {'id': 'Tahoma', 'name': 'افتراضي'},
      {'id': 'Cairo', 'name': 'القاهرة'},
      {'id': 'Amiri', 'name': 'أميري (نسخ)'},
      {'id': 'Aref Ruqaa', 'name': 'عارف رقعة'},
      {'id': 'Reem Kufi', 'name': 'ريم كوفي'},
      {'id': 'Lateef', 'name': 'لطيف (يدوي)'},
      {'id': 'Scheherazade New', 'name': 'شهرزاد'},
      {'id': 'Tajawal', 'name': 'تجوال'},
      {'id': 'Almarai', 'name': 'المراعي'},
      {'id': 'Noto Naskh Arabic', 'name': 'نوتو نسخ'},
      {'id': 'El Messiri', 'name': 'المسيري'},
      {'id': 'Changa', 'name': 'تشانغا'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختر الخط وحجمه', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  
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
                            setState(() {}); 
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              f['name']!, 
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white, 
                                fontFamily: f['id'] == 'Tahoma' ? null : f['id'],
                              )
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Text('حجم الخط (${_styleForTitle ? _titleFontSize.toInt() : _contentFontSize.toInt()})', style: const TextStyle(color: Colors.white)),
                  
                  Slider(
                    value: _styleForTitle ? _titleFontSize : _contentFontSize,
                    min: 12,
                    max: 40,
                    activeColor: Colors.white,
                    onChanged: (val) {
                      setModalState(() {
                        if (_styleForTitle) { _titleFontSize = val; } else { _contentFontSize = val; }
                      });
                      setState(() {});
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

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(images.map((e) => e.path));
      });
    }
  }

  void _viewGallery(int initialIndex) {
    if (_imagePaths.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: _imagePaths.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(File(_imagePaths[index])),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              },
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: PageController(initialPage: initialIndex),
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          if (path != null) {
            _audioRecords.add({'path': path, 'name': 'تسجيل جديد'});
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصوت')));
      } catch (e) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض إذن الميكروفون')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في بدء التسجيل: $e')));
      }
    }
  }

  Future<void> _togglePlayAudio(String path) async {
    if (_currentlyPlayingPath == path) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingPath = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _currentlyPlayingPath = path);
    }
  }

  void _renameAudio(int index) {
    TextEditingController _controller = TextEditingController(text: _audioRecords[index]['name']);
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
              setState(() => _audioRecords[index]['name'] = _controller.text);
              Navigator.pop(context);
            }, 
            child: const Text('حفظ', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  void _insertResult(String result) {
    if (result != 'خطأ') {
      final text = _contentController.text;
      final selection = _contentController.selection;
      if (selection.start == -1) {
        _contentController.text = text + result;
      } else {
        final newText = text.replaceRange(selection.start, selection.end, result);
        _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.start + result.length));
      }
    }
  }

  void _showCalculatorDialog() {
    _calcDisplay = '0'; 
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
              child: GlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الحاسبة', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                      width: double.infinity,
                      child: Text(_calcDisplay, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.1,
                      children: ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', '.', '='].map((e) {
                        bool isEq = e == '=';
                        bool isOp = ['C', '⌫', '%', '÷', '×', '−', '+'].contains(e);
                        
                        return Material(
                          color: isEq ? Colors.white : (isOp ? Colors.white24 : Colors.white.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                if (e == 'C') {
                                  _calcDisplay = '0';
                                } else if (e == '⌫') {
                                  if (_calcDisplay.isNotEmpty && _calcDisplay != '0') {
                                    _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
                                    if (_calcDisplay.isEmpty) _calcDisplay = '0';
                                  }
                                } else if (e == '=') {
                                  try {
                                    String exp = _calcDisplay.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
                                    Parser p = Parser();
                                    Expression expParsed = p.parse(exp);
                                    ContextModel cm = ContextModel();
                                    double eval = expParsed.evaluate(EvaluationType.REAL, cm);
                                    _calcDisplay = eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
                                  } catch (err) {
                                    _calcDisplay = 'خطأ';
                                  }
                                } else {
                                  if (_calcDisplay == '0' && e != '.') {
                                    _calcDisplay = e;
                                  } else {
                                    _calcDisplay += e;
                                  }
                                }
                              });
                            },
                            child: Center(
                              child: Text(
                                e, 
                                style: TextStyle(
                                  fontSize: 22, 
                                  fontWeight: isEq || isOp ? FontWeight.bold : FontWeight.normal,
                                  color: isEq ? Colors.black : Colors.white
                                )
                              )
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _insertResult(_calcDisplay);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.input, size: 20),
                        label: const Text('إدراج النتيجة في النص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF161616).withOpacity(0.9),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  
                  ListTile(
                    leading: const Icon(Icons.alarm, color: Colors.white),
                    title: const Text('تذكير', style: TextStyle(color: Colors.white)),
                    onTap: _setReminder,
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.white),
                    title: const Text('البحث عن نص داخل الملاحظة', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _searchInNote();
                    },
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.copy, color: Colors.white),
                    title: const Text('إنشاء نسخة من الملاحظة', style: TextStyle(color: Colors.white)),
                    onTap: _duplicateNote,
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.white),
                    title: const Text('إرسال', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Share.share('${_titleController.text}\n\n${_contentController.text}');
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
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
    if (_fontFamily == 'Aref Ruqaa') { titleStyle = GoogleFonts.arefRuqaa(textStyle: titleStyle); contentStyle = GoogleFonts.arefRuqaa(textStyle: contentStyle); }
    if (_fontFamily == 'Lateef') { titleStyle = GoogleFonts.lateef(textStyle: titleStyle); contentStyle = GoogleFonts.lateef(textStyle: contentStyle); }
    if (_fontFamily == 'Scheherazade New') { titleStyle = GoogleFonts.scheherazadeNew(textStyle: titleStyle); contentStyle = GoogleFonts.scheherazadeNew(textStyle: contentStyle); }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: _isPinned ? Colors.amber : Colors.white),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: _saveNote),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'جاري التسجيل الآن...',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _toggleRecording,
                      icon: const Icon(Icons.stop, size: 20),
                      label: const Text('إيقاف'),
                    ),
                  ],
                ),
              ),

            TextField(
              controller: _titleController,
              style: titleStyle,
              decoration: const InputDecoration(hintText: 'عنوان الملاحظة...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
            ),
            const Divider(color: Colors.white12),
            
            if (_imagePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _viewGallery(index),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(File(_imagePaths[index])),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _imagePaths.removeAt(index)),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.red, size: 20),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            
            if (_audioRecords.isNotEmpty)
              Column(
                children: List.generate(_audioRecords.length, (index) {
                  final record = _audioRecords[index];
                  bool isPlayingThis = _currentlyPlayingPath == record['path'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            color: isPlayingThis ? Colors.red : Colors.green, 
                            size: 30
                          ), 
                          onPressed: () => _togglePlayAudio(record['path']!)
                        ),
                        Expanded(child: Text(record['name'] ?? 'تسجيل صوتي', style: const TextStyle(color: Colors.white70))),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20), onPressed: () => _renameAudio(index)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => setState(() => _audioRecords.removeAt(index))),
                      ],
                    ),
                  );
                }),
              ),

            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              scrollController: _contentScrollController,
              maxLines: null,
              style: contentStyle,
              decoration: const InputDecoration(hintText: 'اكتب ملاحظتك هنا...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12)), color: Color(0xFF0A0A0A)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.image_outlined, color: Colors.white70), onPressed: _pickImages),
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_none, color: _isRecording ? Colors.red : Colors.white70, size: _isRecording ? 30 : 24), 
                  onPressed: _toggleRecording
                ),
                IconButton(icon: const Icon(Icons.color_lens_outlined, color: Colors.white70), onPressed: _pickColor),
                IconButton(icon: const Icon(Icons.text_fields, color: Colors.white70), onPressed: _pickFont),
                IconButton(icon: const Icon(Icons.calculate_outlined, color: Colors.white70), onPressed: _showCalculatorDialog),
                IconButton(icon: const Icon(Icons.settings, color: Colors.white70), onPressed: _showSettingsSheet),
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
          child: child,
        ),
      ),
    );
  }
}
