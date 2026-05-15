import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  // التأكد من تهيئة واجهات فلاتر
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة البيانات المحلية Hive
  await Hive.initFlutter();

  // تسجيل محول البيانات المالي يدويًا لتجنب الحاجة لملفات خارجية
  Hive.registerAdapter(FinancialRecordAdapter());

  // فتح صندوق تخزين البيانات المالية
  await Hive.openBox<FinancialRecord>('finance_box');

  runApp(const SmartFinanceApp());
}

// ==========================================
// 1. موديل البيانات (Model & Manual Adapter)
// ==========================================
class FinancialRecord {
  final String date; // صيغة التخزين: YYYY-MM-DD
  int morningShifts;
  int eveningShifts;
  double extraIncome;
  double dailyExpenses;

  FinancialRecord({
    required this.date,
    this.morningShifts = 0,
    this.eveningShifts = 0,
    this.extraIncome = 0.0,
    this.dailyExpenses = 0.0,
  });

  double get totalDailyIncome =>
      (morningShifts + eveningShifts) * 12500 + extraIncome;
}

// محول ومفسر البيانات لـ Hive لضمان حفظ الكائنات محلياً بأعلى سرعة وأمان
class FinancialRecordAdapter extends TypeAdapter<FinancialRecord> {
  @override
  final int typeId = 0;

  @override
  FinancialRecord read(BinaryReader reader) {
    return FinancialRecord(
      date: reader.readString(),
      morningShifts: reader.readInt(),
      eveningShifts: reader.readInt(),
      extraIncome: reader.readDouble(),
      dailyExpenses: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, FinancialRecord obj) {
    writer.writeString(obj.date);
    writer.writeInt(obj.morningShifts);
    writer.writeInt(obj.eveningShifts);
    writer.writeDouble(obj.extraIncome);
    writer.writeDouble(obj.dailyExpenses);
  }
}

// ==========================================
// 2. التطبيق الرئيسي وإعدادات الثيم الداكن
// ==========================================
class SmartFinanceApp extends StatelessWidget {
  const SmartFinanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المساعد المالي الذكي',
      // تطبيق واجهة Dark Mode احترافية ومريحة للعين
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ADB5),
          secondary: Colors.greenAccent,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const FinanceHomeScreen(),
    );
  }
}

// ==========================================
// 3. الشاشة الرئيسية وإدارة الحسابات
// ==========================================
class FinanceHomeScreen extends StatefulWidget {
  const FinanceHomeScreen({Key? key}) : super(key: key);

  @override
  State<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends State<FinanceHomeScreen> {
  final Box<FinancialRecord> _financeBox = Hive.box<FinancialRecord>(
    'finance_box',
  );
  final TextEditingController _expenseController = TextEditingController();

  double _totalMonthlyIncome = 0.0;
  double _totalMonthlyExpenses = 0.0;
  double _savedLoan = 0.0;
  double _netBalance = 0.0;
  final double _targetLoan = 250000.0;

  @override
  void initState() {
    super.initState();
    _calculateFinancials();
  }

  // محرك الادخار الذكي: خوارزمية الـ 20 يوم وحساب الأرقام بدقة وحظر مصاريف العمل
  void _calculateFinancials() {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    double tempIncome = 0.0;
    double tempExpenses = 0.0;
    double tempSavedLoan = 0.0;

    // جلب جميع السجلات وتصفيتها للشهر الحالي فقط
    final monthlyRecords = _financeBox.values
        .where((record) => record.date.startsWith(currentMonth))
        .toList();

    for (var record in monthlyRecords) {
      tempIncome += record.totalDailyIncome;
      tempExpenses += record.dailyExpenses;

      // تطبيق خوارزمية الـ 20 يوم الذكية
      int dayNumber = int.parse(record.date.split('-')[2]);
      if (dayNumber <= 20 &&
          (record.morningShifts > 0 || record.eveningShifts > 0)) {
        // حجز شفت واحد بقيمة 12,500 د.ع يومياً لصالح السلفة في أول 20 يوماً فقط
        if (tempSavedLoan < _targetLoan) {
          tempSavedLoan += 12500;
          if (tempSavedLoan > _targetLoan) tempSavedLoan = _targetLoan;
        }
      }
    }

    setState(() {
      _totalMonthlyIncome = tempIncome;
      _totalMonthlyExpenses = tempExpenses;
      _savedLoan = tempSavedLoan;
      // الرصيد الصافي المتاح للصرف = الإيرادات - المصاريف الشخصية - المحجوز للسلفة
      _netBalance = _totalMonthlyIncome - _totalMonthlyExpenses - _savedLoan;
    });
  }

  // نظام تسجيل الدخل بلمسة واحدة للشفتات
  void _addShift({required bool isMorning}) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingRecord = _financeBox.get(today);

    final record = existingRecord ?? FinancialRecord(date: today);
    if (isMorning) {
      record.morningShifts++;
    } else {
      record.eveningShifts++;
    }

    _financeBox.put(today, record);
    _calculateFinancials();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isMorning ? 'تم تسجيل شفت الصباح بنجاح' : 'تم تسجيل شفت المساء بنجاح',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // إضافة دخل الفلتر الدوري (100 ألف كل 15 يوماً)
  void _addFilterIncome() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingRecord = _financeBox.get(today);

    final record = existingRecord ?? FinancialRecord(date: today);
    record.extraIncome += 100000;

    _financeBox.put(today, record);
    _calculateFinancials();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم دمج دخل الفلتر الدوري (+100,000 د.ع)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // إدارة المصاريف الشخصية والمنزلية اليومية وطرحها من المتبقي
  void _addDailyExpense() {
    if (_expenseController.text.isEmpty) return;
    final double? expenseAmount = double.tryParse(_expenseController.text);
    if (expenseAmount == null || expenseAmount <= 0) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existingRecord = _financeBox.get(today);

    final record = existingRecord ?? FinancialRecord(date: today);
    record.dailyExpenses += expenseAmount;

    _financeBox.put(today, record);
    _expenseController.clear();
    FocusScope.of(context).unfocus();
    _calculateFinancials();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل المصروف الشخصي وتحديث الرصيد الصافي'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'en_US');
    double progressPercent = _savedLoan / _targetLoan;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المساعد المالي الشخصي',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة ملخص الرصيد الصافي القابل للصرف
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'الرصيد الصافي المتوفر للصرف الفعلي',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${currencyFormat.format(_netBalance)} د.ع',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(
                            'إجمالي الوارد',
                            '${currencyFormat.format(_totalMonthlyIncome)} د.ع',
                            Colors.greenAccent,
                          ),
                          _buildMiniStat(
                            'المصاريف الشخصية',
                            '${currencyFormat.format(_totalMonthlyExpenses)} د.ع',
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. مؤشرات تقدم ومراقبة هدف السلفة الشهرية
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'مؤشر حجز السلفة (خوارزمية 20 يوم)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(progressPercent * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 12,
                          backgroundColor: Colors.grey[800],
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المؤمن: ${currencyFormat.format(_savedLoan)} د.ع',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'الهدف الثابت: ${currencyFormat.format(_targetLoan)} د.ع',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. أزرار تسجيل الدخل بلمسة واحدة (أزرار الشفتات الذكية)
              const Text(
                'تسجيل الدخل السريع "بلمسة واحدة"',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _addShift(isMorning: true),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildShiftButton(
                        title: 'شفت الصباح',
                        amount: '+12,500 د.ع',
                        icon: Icons.wb_sunny_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _addShift(isMorning: false),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildShiftButton(
                        title: 'شفت المساء',
                        amount: '+12,500 د.ع',
                        icon: Icons.nightlight_round,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. زر دخل الفلتر الـ 15 يومي
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222831),
                  side: const BorderSide(color: Colors.amber, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _addFilterIncome,
                icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                label: const Text(
                  'تسجيل دخل الفلتر الدوري (+100,000 د.ع)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. قسم إدارة المصاريف الشخصية والمنزلية اليومية (بدون تعقيدات مصاريف العمل)
              const Text(
                'تسجيل المصاريف الشخصية والمنزلية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expenseController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'أدخل المبلغ (طعام، نقل، تسوق...)',
                            hintStyle: TextStyle(
                              color: Colors.white30,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _addDailyExpense,
                        child: const Text(
                          'خصم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildShiftButton({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
