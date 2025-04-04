// import 'package:canteendesk/Manager/ManagerReport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({Key? key,}) : super(key: key);

  @override
  _ManagerHomeState createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome>
    with SingleTickerProviderStateMixin {
  // Animation controller
  late AnimationController _animationController;
  bool _isLoading = true;

  // Date range selection
  String _selectedTimeRange = 'Today';
  final List<String> _timeRanges = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month'
  ];

  // Sample data for statistics
  final Map<String, dynamic> statistics = {
    'Total Orders': 25,
    'Completed': 20,
    'Pending': 5,
    'Revenue': 3500
  };

  // Sample trend data (percentage change)
  final Map<String, double> trends = {
    'Total Orders': 5.2,
    'Completed': 8.7,
    'Pending': -2.3,
    'Revenue': 12.5
  };

  // Sample data for charts
  final List<FlSpot> revenueSpots = [
    FlSpot(0, 1500),
    FlSpot(1, 2200),
    FlSpot(2, 1800),
    FlSpot(3, 2400),
    FlSpot(4, 2900),
    FlSpot(5, 3200),
    FlSpot(6, 3500),
  ];

  final List<FlSpot> ordersSpots = [
    FlSpot(0, 12),
    FlSpot(1, 18),
    FlSpot(2, 14),
    FlSpot(3, 20),
    FlSpot(4, 22),
    FlSpot(5, 23),
    FlSpot(6, 25),
  ];

  final List<Map<String, dynamic>> popularItems = [
    {
      "image": "assets/img/momo.jpeg",
      "name": "Momos",
      "sold": 32,
      "revenue": 2240,
      "category": "Appetizers",
      "trend": 12.5
    },
    {
      "image": "assets/img/pizza.jpeg",
      "name": "Pizza",
      "sold": 28,
      "revenue": 3080,
      "category": "Main Course",
      "trend": 8.2
    },
    {
      "image": "assets/img/fried_rice.jpeg",
      "name": "Fried Rice",
      "sold": 25,
      "revenue": 1500,
      "category": "Main Course",
      "trend": -3.4
    },
    {
      "image": "assets/img/spring rolls.jpeg",
      "name": "Spring Rolls",
      "sold": 22,
      "revenue": 2640,
      "category": "Fast Food",
      "trend": 5.8
    },
    {
      "image": "assets/img/veg noodles.jpeg",
      "name": "Noodles",
      "sold": 20,
      "revenue": 1600,
      "category": "Main Course",
      "trend": 7.3
    },
  ];

  final List<String> categories = [
    'All',
    'Appetizers',
    'Main Course',
    'Fast Food',
    'Desserts',
    'Beverages'
  ];
  String _selectedCategory = 'All';

  // Selected index for navigation rail
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Simulate data loading
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // FIXED: Schedule updating the pending order count after the first frame is built
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   widget.updatePendingOrderCount(statistics['Pending'] as int);
    // });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to safely update state for category changes
  void _updateCategory(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
        _isLoading = true;
      });

      // Simulate data loading for category change
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  // Method to safely handle time range changes
  void _updateTimeRange(String? value) {
    if (value != null && _selectedTimeRange != value) {
      setState(() {
        _selectedTimeRange = value;
        _isLoading = true;
      });

      // Simulate data refresh when timerange changes
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  // Method to update selected index for navigation rail
  // void _onDestinationSelected(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  //   if (index == 1) {
  //     Navigator.of(context).push(
  //          MaterialPageRoute(builder: (context) => ManagerReport()),
  //         );
  //   }
  // }

  @override
 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWideLayout();
        } else {
          return _buildNarrowLayout();
        }
      },
    ),
  );
}

  Widget _buildWideLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(),
                const SizedBox(height: 20),
                _isLoading
                    ? _buildStatisticsShimmer()
                    : _buildStatisticsCards(),
                const SizedBox(height: 24),
                _isLoading ? _buildChartsShimmer() : _buildCharts(),
                const SizedBox(height: 24),
                _buildPopularItemsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(),
                const SizedBox(height: 20),
                _isLoading
                    ? _buildStatisticsShimmer()
                    : _buildStatisticsCards(),
                const SizedBox(height: 24),
                _isLoading ? _buildChartsShimmer() : _buildCharts(),
                const SizedBox(height: 24),
                _buildPopularItemsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEEE, MMM d, yyyy')
                .format(DateTime.parse("2025-03-06 17:34:01")),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimeRange,
                icon: Icon(Icons.keyboard_arrow_down,
                    size: 20, color: Colors.grey[700]),
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                items: _timeRanges
                    .map((range) =>
                        DropdownMenuItem(value: range, child: Text(range)))
                    .toList(),
                onChanged: _updateTimeRange,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).moveX(
              begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .moveY(begin: -10, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildStatisticsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final List<LinearGradient> gradients = [
      LinearGradient(
          colors: [Color(0xFF6448FE), Color(0xFF5FC6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFF2ECE7B), Color(0xFF33D890)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFFFE9A37), Color(0xFFFFB566)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      LinearGradient(
          colors: [Color(0xFFFF5182), Color(0xFFFF7B9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
    ];

    final List<IconData> icons = [
      Icons.shopping_bag_rounded,
      Icons.check_circle_outlined,
      Icons.pending_actions_outlined,
      Icons.currency_rupee_rounded,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: gradients[index],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradients[index].colors.first.withAlpha(76),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(icons[index], color: Colors.white, size: 22),
                      ),
                      Row(
                        children: [
                          Icon(
                            trends[statistics.keys.elementAt(index)]! >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trends[statistics.keys.elementAt(index)]!.abs().toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statistics.keys.elementAt(index) == "Revenue"
                        ? "₹${NumberFormat('#,###').format(statistics[statistics.keys.elementAt(index)])}"
                        : statistics[statistics.keys.elementAt(index)]
                            .toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    statistics.keys.elementAt(index),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(229),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChartsShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 180,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Trends',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800]),
        ).animate().fadeIn(duration: 400.ms).moveX(
            begin: -20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue (Last 7 Days)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const style = TextStyle(
                                      color: Color(0xff68737d),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10);
                                  String text;
                                  switch (value.toInt()) {
                                    case 0:
                                      text = 'Mon';
                                      break;
                                    case 3:
                                      text = 'Thu';
                                      break;
                                    case 6:
                                      text = 'Sun';
                                      break;
                                    default:
                                      text = '';
                                      break;
                                  }
                                  return SideTitleWidget(
                                      meta: meta,
                                      space: 4,
                                      child: Text(text, style: style));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: revenueSpots,
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                  show: true, color: Colors.blue.withAlpha(51)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(
                  begin: -0.2,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutQuad),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders (Last 7 Days)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const style = TextStyle(
                                    color: Color(0xff68737d),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  );
                                  String text;
                                  switch (value.toInt()) {
                                    case 0:
                                      text = 'Mon';
                                      break;
                                    case 3:
                                      text = 'Thu';
                                      break;
                                    case 6:
                                      text = 'Sun';
                                      break;
                                    default:
                                      text = '';
                                      break;
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 4,
                                    child: Text(text, style: style),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: ordersSpots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withAlpha(51),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(
                  begin: 0.2,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutQuad),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPopularItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms).moveX(
                begin: -20,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutQuad),
            TextButton(
              onPressed: () {
                // Navigate to full menu
              },
              child: Text(
                'View all',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms).moveX(
                begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
          ],
        ),
        const SizedBox(height: 8),

        // Categories
        _isLoading ? _buildCategoriesShimmer() : _buildCategories(),
        const SizedBox(height: 16),

        // Popular items horizontal list
        _isLoading ? _buildPopularItemsListShimmer() : _buildPopularItemsList(),
      ],
    );
  }

  Widget _buildCategoriesShimmer() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () {
              // FIXED: Using safe method to update category
              _updateCategory(category);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 600.ms + (50.ms * index))
                .slideX(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad),
          );
        },
      ),
    );
  }

  Widget _buildPopularItemsListShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularItemsList() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularItems.length,
        itemBuilder: (context, index) {
          final item = popularItems[index];
          final isPositiveTrend = item["trend"] >= 0;

          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item image with shimmer effect on load
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.asset(
                        item["image"],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositiveTrend
                              ? Colors.green.withAlpha(229)
                              : Colors.red.withAlpha(229),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositiveTrend
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item["trend"].abs().toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item["category"],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sold: ${item["sold"]}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${NumberFormat('#,###').format(item["revenue"])}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 700.ms + (100.ms * index), duration: 500.ms)
              .slideX(
                  begin: 0.2,
                  end: 0,
                  delay: 700.ms + (100.ms * index),
                  duration: 400.ms,
                  curve: Curves.easeOutQuad)
              .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                  delay: 2.seconds)
              .shimmer(
                  duration: 1.seconds,
                  angle: 0.5,
                  color: Colors.white.withAlpha(51));
        },
      ),
    );
  }

  Widget _buildQuickActionsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          4,
          (index) => Container(
            width: 70,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

//   // Method to handle action tap safely - prevents setState during build
//   // void _handleActionTap(Map<String, dynamic> action) {
//   //   if (action['title'] == 'Manage Menu') {
//   //     Navigator.push(
//   //       context,
//   //       MaterialPageRoute(builder: (context) => ManagerManageMenu()),
//   //     );
//   //   } else if (action['title'] == 'Manage Payment') {
//   //     Navigator.push(
//   //       context,
//   //       MaterialPageRoute(builder: (context) => ManagerPaymentMethods()),
//   //     );
//   //   }
//   // }
 }
