import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ==========================================
// 1. نظام التنبيهات الذكي (Notification Service)
// ==========================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notificationsPlugin.initialize(initSettings);
  }

  // جدولة تنبيه يومي في الساعة 9 مساءً
  static Future<void> scheduleDailyReminder() async {
    await _notificationsPlugin.zonedSchedule(
      0,
      'تذكير مالي 💰',
      'هل نسيت تسجيل مصاريف اليوم؟ حافظ على دقة حساباتك!',
      _nextInstanceOfNinePM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'تذكير يومي',
          channelDescription: 'قناة تذكير لتسجيل المصاريف اليومية',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // تكرار يومي
    );
  }

  static tz.TZDateTime _nextInstanceOfNinePM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21,
      0,
    ); // 9:00 PM
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotificationService.init(); // تشغيل نظام التنبيهات
  await NotificationService.scheduleDailyReminder(); // تفعيل التذكير اليومي تلقائياً

  Hive.registerAdapter(FinancialRecordAdapter());
  await Hive.openBox<FinancialRecord>('finance_box');
  await Hive.openBox('settings_box');

  runApp(const SmartFinanceApp());
}

// [موديلات البيانات FinancialRecord و FinancialRecordAdapter تبقى كما هي في الكود السابق]
@HiveType(typeId: 0)
class FinancialRecord {
  @HiveField(0)
  final String date;
  @HiveField(1)
  int morningShifts;
  @HiveField(2)
  int eveningShifts;
  @HiveField(3)
  double extraIncome;
  @HiveField(4)
  double dailyExpenses;

  FinancialRecord({
    required this.date,
    this.morningShifts = 0,
    this.eveningShifts = 0,
    this.extraIncome = 0.0,
    this.dailyExpenses = 0.0,
  });
}

class FinancialRecordAdapter extends TypeAdapter<FinancialRecord> {
  @override
  final int typeId = 0;
  @override
  FinancialRecord read(BinaryReader reader) {
    return FinancialRecord(
      date: reader.read(),
      morningShifts: reader.read(),
      eveningShifts: reader.read(),
      extraIncome: reader.read(),
      dailyExpenses: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, FinancialRecord obj) {
    writer.write(obj.date);
    writer.write(obj.morningShifts);
    writer.write(obj.eveningShifts);
    writer.write(obj.extraIncome);
    writer.write(obj.dailyExpenses);
  }
}

class SmartFinanceApp extends StatelessWidget {
  const SmartFinanceApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        cardColor: const Color(0xFF1A1D29),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ADB5),
          secondary: Colors.amber,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00ADB5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'السجل'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'الإحصائيات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. الشاشة الرئيسية مع العد التنازلي (HomeScreen)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box<FinancialRecord> _box = Hive.box<FinancialRecord>('finance_box');
  final Box _settings = Hive.box('settings_box');
  final TextEditingController _expCtrl = TextEditingController();

  double _netBalance = 0, _totalCapital = 0, _savedLoan = 0;
  int _daysUntilFilter = 0; // متطلبات ميزة العد التنازلي
  final currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    double tempTotalInc = 0,
        tempTotalExp = 0,
        tempMonthlyInc = 0,
        tempMonthlyExp = 0,
        tempSavedLoan = 0;
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);

    double shiftPrice = _settings.get('shiftPrice', defaultValue: 12500.0);
    double loanTarget = _settings.get('loanTarget', defaultValue: 250000.0);

    for (var r in _box.values) {
      double inc =
          (r.morningShifts + r.eveningShifts) * shiftPrice + r.extraIncome;
      tempTotalInc += inc;
      tempTotalExp += r.dailyExpenses;
      if (r.date.startsWith(currentMonth)) {
        tempMonthlyInc += inc;
        tempMonthlyExp += r.dailyExpenses;
        int day = int.parse(r.date.split('-')[2]);
        if (day <= 20 && (r.morningShifts > 0 || r.eveningShifts > 0)) {
          if (tempSavedLoan < loanTarget) tempSavedLoan += shiftPrice;
        }
      }
    }

    // حساب العد التنازلي لمدفوع الـ 15 يوماً (دخل الفلتر)
    int currentDay = now.day;
    if (currentDay <= 15) {
      _daysUntilFilter = 15 - currentDay;
    } else {
      int lastDay = DateTime(now.year, now.month + 1, 0).day;
      _daysUntilFilter = lastDay - currentDay;
    }

    setState(() {
      _totalCapital = tempTotalInc - tempTotalExp;
      _savedLoan = tempSavedLoan > loanTarget ? loanTarget : tempSavedLoan;
      _netBalance = tempMonthlyInc - tempMonthlyExp - _savedLoan;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة الذكية'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ميزة العد التنازلي (Filter Income Countdown)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _daysUntilFilter == 0
                        ? "اليوم موعد استلام دخل الفلتر! 🎁"
                        : "بقي $_daysUntilFilter أيام على استلام 100 ألف (دخل الفلتر)",
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusCard(
              'إجمالي النقد المتوفر (الخزنة)',
              _totalCapital,
              Colors.amber,
              Icons.account_balance_wallet,
            ),
            const SizedBox(height: 12),
            _buildStatusCard(
              'رصيد الصرف (هذا الشهر)',
              _netBalance,
              const Color(0xFF00ADB5),
              Icons.savings,
            ),
            const SizedBox(height: 20),
            _buildLoanProgress(),
            const SizedBox(height: 25),
            Row(
              children: [
                _buildQuickBtn(
                  'شفت صباح',
                  () => _addShift(true),
                  Colors.orange,
                ),
                const SizedBox(width: 10),
                _buildQuickBtn('شفت مساء', () => _addShift(false), Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionBtn(
              'تسجيل دخل الفلتر (+100 ألف)',
              _addFilter,
              Colors.green,
            ),
            const SizedBox(height: 25),
            _buildExpenseInput(),
          ],
        ),
      ),
    );
  }

  // [بقية التوابع _buildStatusCard, _buildLoanProgress, _buildQuickBtn, _buildActionBtn, _buildExpenseInput, _addShift, _addFilter, _saveExpense تبقى كما هي]
  Widget _buildStatusCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '${currencyFormat.format(amount)} د.ع',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanProgress() {
    double target = _settings.get('loanTarget', defaultValue: 250000.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'هدف السلفة الشهرية',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${(_savedLoan / target * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _savedLoan / target,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _buildQuickBtn(String label, VoidCallback tap, Color color) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          side: BorderSide(color: color),
        ),
        onPressed: tap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActionBtn(String label, VoidCallback tap, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: tap,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D29),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _expCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'سجل مصروف شخصي...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
            onPressed: _saveExpense,
          ),
        ],
      ),
    );
  }

  void _addShift(bool isMorning) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var rec = _box.get(today) ?? FinancialRecord(date: today);
    isMorning ? rec.morningShifts++ : rec.eveningShifts++;
    _box.put(today, rec);
    _refreshData();
  }

  void _addFilter() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var rec = _box.get(today) ?? FinancialRecord(date: today);
    rec.extraIncome += _settings.get('filterPrice', defaultValue: 100000.0);
    _box.put(today, rec);
    _refreshData();
  }

  void _saveExpense() {
    if (_expCtrl.text.isEmpty) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var rec = _box.get(today) ?? FinancialRecord(date: today);
    rec.dailyExpenses += double.parse(_expCtrl.text);
    _box.put(today, rec);
    _expCtrl.clear();
    _refreshData();
  }
}

// [بقيه الشاشات History, Analytics, Settings تبقى كما هي في الكود السابق]
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final box = Hive.box<FinancialRecord>('finance_box');
    final records = box.values.toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات'), centerTitle: true),
      body: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final rec = records[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: Color(0xFF00ADB5),
              ),
              title: Text(
                rec.date,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'شفتات: ${rec.morningShifts + rec.eveningShifts} | مصاريف: ${rec.dailyExpenses}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: () {
                  box.deleteAt(box.values.length - 1 - index);
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final box = Hive.box<FinancialRecord>('finance_box');
    double totalIn = 0, totalOut = 0;
    for (var r in box.values) {
      totalIn += (r.morningShifts + r.eveningShifts) * 12500 + r.extraIncome;
      totalOut += r.dailyExpenses;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('تحليل البيانات'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pie_chart, size: 100, color: Color(0xFF00ADB5)),
            const SizedBox(height: 20),
            Text(
              'إجمالي الوارد: ${totalIn.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontSize: 18, color: Colors.greenAccent),
            ),
            Text(
              'إجمالي المصاريف: ${totalOut.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontSize: 18, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = Hive.box('settings_box');
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingItem('قيمة الشفت الواحدة', 'shiftPrice', 12500.0),
          _buildSettingItem('هدف السلفة الشهرية', 'loanTarget', 250000.0),
          _buildSettingItem('مبلغ دخل الفلتر', 'filterPrice', 100000.0),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('مسح جميع البيانات'),
            onTap: () => Hive.box<FinancialRecord>('finance_box').clear(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String key, double defaultVal) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        'الحالي: ${_settings.get(key, defaultValue: defaultVal)} د.ع',
      ),
      trailing: const Icon(Icons.edit, size: 20),
      onTap: () => _showEditDialog(title, key),
    );
  }

  void _showEditDialog(String title, String key) {
    TextEditingController c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل $title'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'أدخل القيمة الجديدة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _settings.put(key, double.parse(c.text));
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
