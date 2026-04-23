import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/customer.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<Customer> _customers = [
    Customer(id: '1', name: 'أحمد محمد', phone: '01001234567', needs: 'شقة 3 غرف', status: 'Hot', lastContact: 'اليوم'),
    Customer(id: '2', name: 'سارة محمود', phone: '01223456789', needs: 'فيلا استثمار', status: 'Warm', lastContact: 'أمس'),
    Customer(id: '3', name: 'ياسين علي', phone: '01112223334', needs: 'محل تجاري', status: 'Cold', lastContact: 'منذ أسبوع'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم - المبيعات'),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacementNamed(context, '/')),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مرحبًا، أحمد! 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildStatsCards(),
              const SizedBox(height: 24),
              const Text('نشاط المبيعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart(),
              const SizedBox(height: 24),
              const Text('العملاء الحاليين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCustomersTable(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {}, // Add customer dialog
          label: const Text('إضافة عميل'),
          icon: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('عملاء جدد', '12', Icons.people, Colors.blue),
        _buildStatCard('جولات اليوم', '5', Icons.calendar_today, Colors.orange),
        _buildStatCard('صفقات متوقعة', '2', Icons.handshake, Colors.green),
        _buildStatCard('عمولتك', '15k', Icons.payments, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 3), FlSpot(2, 5), FlSpot(4, 4), FlSpot(6, 8)],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('الاسم')),
          DataColumn(label: Text('الرقم')),
          DataColumn(label: Text('الاحتياجات')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('آخر تواصل')),
        ],
        rows: _customers.map((c) => DataRow(cells: [
          DataCell(Text(c.name)),
          DataCell(Text(c.phone)),
          DataCell(Text(c.needs)),
          DataCell(Chip(label: Text(c.status), backgroundColor: c.statusColor.withOpacity(0.2))),
          DataCell(Text(c.lastContact)),
        ])).toList(),
      ),
    );
  }
}
