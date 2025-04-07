import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

class ManagerReport extends StatefulWidget {
  @override
  _ManagerReportState createState() => _ManagerReportState();
}

class _ManagerReportState extends State<ManagerReport> {
  int _selectedChartTypeIndex = 0;
  String selectedTimeFrame = 'Weekly';
  List<String> timeFrames = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  bool _isLoading = true;
  final List<String> _chartTypes = ['Bar', 'Line', 'Pie'];

  final List<Map<String, dynamic>> salesData = [
    {'day': 'Mon', 'sales': 2500},
    {'day': 'Tue', 'sales': 1800},
    {'day': 'Wed', 'sales': 3200},
    {'day': 'Thu', 'sales': 2700},
    {'day': 'Fri', 'sales': 4100},
    {'day': 'Sat', 'sales': 5400},
    {'day': 'Sun', 'sales': 4800},
  ];
  final List<Map<String, dynamic>> categories = [
    {'name': 'Fast Food', 'sales': 'Rs. 5,200', 'percentage': 45, 'color': Colors.blue},
    {'name': 'Beverages', 'sales': 'Rs. 3,100', 'percentage': 27, 'color': Colors.orange},
    {'name': 'Desserts', 'sales': 'Rs. 2,500', 'percentage': 21, 'color': Colors.green},
    {'name': 'Main Course', 'sales': 'Rs. 800', 'percentage': 7, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    // Simulate data loading
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
  
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading ? _buildLoadingView() : _buildReportContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerHeader(),
          const SizedBox(height: 20),
          _buildShimmerChart(),
          const SizedBox(height: 30),
          _buildShimmerCategoryTitle(),
          const SizedBox(height: 16),
          _buildShimmerCategories(),
          const SizedBox(height: 30),
          _buildShimmerActions(),
        ],
      ),
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 30,
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
          ),
          Container(
            height: 30,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerChart() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShimmerCategoryTitle() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 24,
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShimmerCategories() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      height: 16,
                      width: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerActions() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Container(
            height: 40,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
 Widget _buildReportContent() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader()
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: -0.2, end: 0),
        const SizedBox(height: 20),
        _buildChartSelector()
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms),
        const SizedBox(height: 20),

        // --- Side by side chart and top categories ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildChart()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 800.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Categories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 600.ms),
                  const SizedBox(height: 16),
                  _buildCategoryStats()
                      .animate()
                      .fadeIn(delay: 1000.ms, duration: 600.ms),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildSummaryCards(context)
            .animate()
            .fadeIn(delay: 1200.ms, duration: 600.ms),
        const SizedBox(height: 30),
       
      ],
    ),
  );
}

  
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Reports',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Text(
              'Restaurant performance',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButton<String>(
            value: selectedTimeFrame,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            underline: const SizedBox(),
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedTimeFrame = newValue;
                });
              }
            },
            items: timeFrames.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChartSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _chartTypes.length,
          (index) => GestureDetector(
            onTap: () {
              setState(() {
                _selectedChartTypeIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedChartTypeIndex == index
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _chartTypes[index],
                style: TextStyle(
                  color: _selectedChartTypeIndex == index
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                .animate(target: _selectedChartTypeIndex == index ? 1 : 0)
                .scaleXY(end: 1.05, duration: 200.ms)
                .then()
                .scaleXY(end: 1.0, duration: 200.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
  return Center(
    child: SizedBox(
      width: 800, // Set your desired max width here
      child: Container(
        height: 450,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(25),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _getSelectedChart(),
      ),
    ),
  );
}


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
        centerSpaceRadius: 70,
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
Widget _buildSummaryCards(BuildContext context) {
  final List<Map<String, dynamic>> summaries = [
    {
      'title': 'Total Sales',
      'value': '11,600',
      'change': '+8.2%',
      'isPositive': true,
      'icon': Icons.trending_up,
    },
    {
      'title': 'Orders',
      'value': '142',
      'change': '+12.5%',
      'isPositive': true,
      'icon': Icons.shopping_bag,
    },
    {
      'title': 'Avg. Order Value',
      'value': 'Rs. 816',
      'change': '-2.1%',
      'isPositive': false,
      'icon': Icons.attach_money,
    },
  ];

  final List<Map<String, dynamic>> actions = [
    {'icon': Icons.share, 'label': 'Share', 'color': Colors.green[700]!},
    {'icon': Icons.download, 'label': 'Download', 'color': Colors.orange[700]!},
  ];

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards - scrollable if needed
        Expanded(
          child: SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final item = summaries[index];
                return Container(
                  width: MediaQuery.of(context).size.width * 0.18,
                  margin: EdgeInsets.only(right: index < summaries.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['title'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Icon(
                            item['icon'],
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['value'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item['isPositive']
                                  ? Colors.green.withAlpha(25)
                                  : Colors.red.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item['change'],
                              style: TextStyle(
                                fontSize: 12,
                                color: item['isPositive']
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(delay: (index * 200).ms, duration: 400.ms);
              },
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Action Buttons
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: actions.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> action = entry.value;

            return Padding(
              padding: EdgeInsets.only(bottom: index == 0 ? 60 : 0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Handle action
                },
                icon: Icon(action['icon']),
                label: Text(action['label']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: action['color'],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ).animate().fadeIn(delay: (index * 200).ms, duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            );
          }).toList(),
        )
      ],
    ),
  );
}


  Widget _buildCategoryStats() {
    return Column(
      children: categories.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> category = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(12),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: category['color'],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      category['sales'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      width: MediaQuery.of(context).size.width *
                          (category['percentage'] as int) / 100 * 0.83,
                      height: 8,
                      decoration: BoxDecoration(
                        color: category['color'],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ).animate(delay: (100 * index).ms).slideX(
                          begin: -1,
                          end: 0,
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${category['percentage']}% of total sales',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 200).ms, duration: 400.ms)
         .slideY(begin: 0.2, end: 0);
      }).toList(),
    );
  }
 }
  