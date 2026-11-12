import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:math_expressions/math_expressions.dart';
import 'package:image_picker/image_picker.dart';

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
  int _currentIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // القائمة الجانبية
      drawer: _buildDrawer(),
      
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu), 
          onPressed: () => Scaffold.of(context).openDrawer()
        ),
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'ابحث عن ملاحظة...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            )
          : Text(_getTitleByIndex(_currentIndex), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search), 
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            }
          ),
        ],
      ),
      body: Column(
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

                // منطق الفلترة (بحث + تصنيف + تابات)
                final filteredNotes = allNotes.where((entry) {
                  final note = entry.value;
                  final title = note['title'] ?? '';
                  final content = note['content'] ?? '';
                  final category = note['category'] ?? 'عام';
                  final isArchived = note['isArchived'] ?? false;
                  final isFavorite = note['isFavorite'] ?? false;

                  // 1. فلترة البحث
                  bool matchesSearch = title.contains(_searchQuery) || content.contains(_searchQuery);

                  // 2. فلترة التاب السفلي
                  bool matchesTab = false;
                  if (_currentIndex == 0) matchesTab = !isArchived; // الرئيسية (غير المؤرشف)
                  if (_currentIndex == 1) matchesTab = isArchived; // الأرشيف
                  if (_currentIndex == 2) matchesTab = isFavorite && !isArchived; // المفضلة

                  // 3. فلترة التصنيف
                  bool matchesCategory = selectedCategory == 'الكل' || category == selectedCategory;

                  return matchesSearch && matchesTab && matchesCategory;
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
      floatingActionButton: _currentIndex == 3 ? null : FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddNoteScreen())),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _isSearching = false;
          });
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

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          border: Border(left: BorderSide(color: Colors.white12)),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF222222),
                    child: Icon(Icons.person, size: 50, color: Colors.white54),
                  ),
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
            const Divider(color: Colors.white12),
            _buildDrawerItem(Icons.info_outline, 'حول التطبيق', () {
              Navigator.pop(context);
              showAboutDialog(context: context, applicationName: 'ملاحظاتي', applicationVersion: '1.0.0');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
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
    bool isFav = note['isFavorite'] ?? false;
    return InkWell(
      onTap: () {
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
                Row(
                  children: [
                    // زر المفضلة
                    IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.white38, size: 22),
                      onPressed: () {
                        // تحديث حالة المفضلة
                        Map updatedNote = Map.from(note);
                        updatedNote['isFavorite'] = !isFav;
                        box.put(noteKey, updatedNote);
                      },
                    ),
                    // زر الأرشفة
                    IconButton(
                      icon: const Icon(Icons.archive_outlined, color: Colors.white38, size: 20),
                      onPressed: () {
                        Map updatedNote = Map.from(note);
                        updatedNote['isArchived'] = true;
                        box.put(noteKey, updatedNote);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الأرشفة')));
                      },
                    ),
                    // زر الحذف
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _showDeleteConfirmation(context, box, noteKey),
                    ),
                  ],
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
          TextButton(
            onPressed: () {
              box.delete(noteKey);
              Navigator.pop(context);
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
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
  
  bool _isCalcOpen = false;
  String _calcDisplay = '0';

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
        Hive.box('notes').add({
          'title': _titleController.text,
          'content': _contentController.text,
          'category': _selectedCategory,
          'date': dateStr,
          'time': timeStr,
          'isFavorite': false,
          'isArchived': false,
        });
      } else {
        Hive.box('notes').put(widget.noteKey, {
          'title': _titleController.text,
          'content': _contentController.text,
          'category': _selectedCategory,
          'date': widget.note!['date'], 
          'time': widget.note!['time'],
          'isFavorite': widget.note!['isFavorite'] ?? false,
          'isArchived': widget.note!['isArchived'] ?? false,
        });
      }
      Navigator.pop(context);
    }
  }

  void _onCalcButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _calcDisplay = '0';
      } else if (value == '⌫') {
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

  void _insertResult() {
    if (_calcDisplay != 'خطأ') {
      final text = _contentController.text;
      final selection = _contentController.selection;
      
      if (selection.start == -1) {
        _contentController.text = text + _calcDisplay;
      } else {
        final newText = text.replaceRange(selection.start, selection.end, _calcDisplay);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + _calcDisplay.length),
        );
      }
      setState(() => _isCalcOpen = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
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
