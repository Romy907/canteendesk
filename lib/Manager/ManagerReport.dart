import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManagerReport extends StatefulWidget {
  @override
  _ManagerReportState createState() => _ManagerReportState();
}

class _ManagerReportState extends State<ManagerReport> {
  int _selectedChartTypeIndex = 0;

  final List<Map<String, dynamic>> salesData = [
    {'day': 'Mon', 'sales': 1200},
    {'day': 'Tue', 'sales': 2200},
    {'day': 'Wed', 'sales': 1800},
    {'day': 'Thu', 'sales': 2600},
    {'day': 'Fri', 'sales': 1900},
  ];

  final List<Map<String, dynamic>> categories = [
    {'name': 'Electronics', 'sales': 'Rs. 4,200', 'percentage': 36, 'color': Colors.blue},
    {'name': 'Clothing', 'sales': 'Rs. 3,200', 'percentage': 27, 'color': Colors.red},
    {'name': 'Home', 'sales': 'Rs. 2,100', 'percentage': 18, 'color': Colors.green},
    {'name': 'Beauty', 'sales': 'Rs. 1,800', 'percentage': 15, 'color': Colors.purple},
    {'name': 'Other', 'sales': 'Rs. 300', 'percentage': 4, 'color': Colors.grey},
  ];

  Widget _getSelectedChart() {
    switch (_selectedChartTypeIndex) {
      case 0:
        return _buildBarChart();
      case 1:
        return _buildLineChart();
      case 2:
        return _buildPieChart();
      default:
        return _buildBarChart();
    }
  }

  Widget _buildBarChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 6000,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    'Rs. ${salesData[groupIndex]['sales']}',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      salesData[value.toInt()]['day'],
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 16 : 12,
                      ),
                    ),
                  ),
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 1000,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      value == 0 ? '0' : '${(value / 1000).toInt()}K',
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 14 : 10,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              salesData.length,
              (index) => BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: salesData[index]['sales'].toDouble(),
                    color: Theme.of(context).primaryColor,
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 6000,
                      color: Colors.grey.withAlpha(25),
                    ),
                  ),
                ],
              ),
            ),
            gridData: FlGridData(
              show: true,
              checkToShowHorizontalLine: (value) => value % 1000 == 0,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withAlpha(51),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return LineChart(
          LineChartData(
            lineTouchData: LineTouchData(handleBuiltInTouches: true),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1000,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withAlpha(51),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      salesData[value.toInt()]['day'],
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 16 : 12,
                      ),
                    ),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1000,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      value == 0 ? '0' : '${(value / 1000).toInt()}K',
                      style: TextStyle(
                        color: const Color(0xff7589a2),
                        fontWeight: FontWeight.bold,
                        fontSize: constraints.maxWidth > 800 ? 14 : 10,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: salesData.length - 1.0,
            minY: 0,
            maxY: 6000,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  salesData.length,
                  (index) => FlSpot(index.toDouble(), salesData[index]['sales'].toDouble()),
                ),
                isCurved: true,
                color: Theme.of(context).primaryColor,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).primaryColor.withAlpha(51),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(
          categories.length,
          (index) => PieChartSectionData(
            color: categories[index]['color'],
            value: categories[index]['percentage'].toDouble(),
            title: '${categories[index]['percentage']}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Report'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildSummaryCard('Total Sales', 'Rs. 15,000', Icons.trending_up),
                    _buildSummaryCard('Orders', '1,200', Icons.shopping_cart),
                    _buildSummaryCard('Customers', '980', Icons.people),
                  ],
                ),
                const SizedBox(height: 24),

                // Chart and Controls
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildChartCard()),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _buildCategoryStatsCard()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildChartCard(),
                          const SizedBox(height: 16),
                          _buildCategoryStatsCard(),
                        ],
                      ),

                const SizedBox(height: 24),
                // Export Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export Report'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(title, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Chart Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartToggle('Bar', 0),
                const SizedBox(width: 12),
                _buildChartToggle('Line', 1),
                const SizedBox(width: 12),
                _buildChartToggle('Pie', 2),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _getSelectedChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartToggle(String label, int index) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedChartTypeIndex == index,
      onSelected: (_) {
        setState(() {
          _selectedChartTypeIndex = index;
        });
      },
    );
  }

  Widget _buildCategoryStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Column(
              children: categories
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: category['color'], radius: 6),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(category['name'], style: const TextStyle(fontSize: 14)),
                          ),
                          Text(category['sales'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('${category['percentage']}%', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
