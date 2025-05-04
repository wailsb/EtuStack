import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/database_helper_new.dart';
import '../utils/app_constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;
  bool _isLoading = true;
  
  // Date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Statistics data
  double _totalRevenue = 0;
  double _totalProfit = 0;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topClients = [];
  List<Map<String, dynamic>> _monthlySales = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Format dates for SQLite
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));
      
      // Get revenue and profit for the selected period
      final revenue = await _dbHelper.getTotalRevenueInRange(startDateStr, endDateStr);
      final profit = await _dbHelper.getTotalProfitInRange(startDateStr, endDateStr);
      
      // Get top products and clients
      final topProductsData = await _dbHelper.getTopSellingProducts(5);
      final topClientsData = await _dbHelper.getTopClients(5);
      
      // Monthly sales would normally come from the DB, but for demo purposes,
      // we'll generate some random data for the past 6 months
      final monthlySales = _generateMonthlySalesData();
      
      setState(() {
        _totalRevenue = revenue;
        _totalProfit = profit;
        _topProducts = topProductsData['products'] as List<Map<String, dynamic>>;
        _topClients = topClientsData['clients'] as List<Map<String, dynamic>>;
        _monthlySales = monthlySales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }
  
  List<Map<String, dynamic>> _generateMonthlySalesData() {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    
    for (int i = 5; i >= 0; i--) {
      final month = now.month - i;
      final year = now.year + (month <= 0 ? -1 : 0);
      final adjustedMonth = month <= 0 ? month + 12 : month;
      
      final date = DateTime(year, adjustedMonth);
      final revenue = 1000.0 + (DateTime.now().millisecondsSinceEpoch % 5000).toDouble();
      final profit = revenue * 0.3;
      
      result.add({
        'date': date,
        'revenue': revenue,
        'profit': profit,
      });
    }
    
    return result;
  }
  
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConstants.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Range Selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text('Date Range: '),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectDateRange(context),
                          child: Text(
                            '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDashboardData,
                        tooltip: 'Refresh Data',
                      ),
                    ],
                  ),
                ),
                
                // Dashboard Summary Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Revenue',
                          '\$${_totalRevenue.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green.shade400,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Profit',
                          '\$${_totalProfit.toStringAsFixed(2)}',
                          Icons.trending_up,
                          Colors.blue.shade400,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Profit Margin',
                          _totalRevenue > 0
                              ? '${((_totalProfit / _totalRevenue) * 100).toStringAsFixed(1)}%'
                              : '0%',
                          Icons.pie_chart,
                          Colors.purple.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab Bar for different statistics
                TabBar(
                  controller: _tabController,
                  labelColor: AppConstants.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Sales Trends'),
                    Tab(text: 'Top Products'),
                    Tab(text: 'Top Clients'),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesTrendsTab(),
                      _buildTopProductsTab(),
                      _buildTopClientsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSalesTrendsTab() {
    if (_monthlySales.isEmpty) {
      return const Center(child: Text('No sales data available'));
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Sales Trends',
            style: AppConstants.subheadingStyle,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _monthlySales.length) {
                          final date = _monthlySales[value.toInt()]['date'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: const TextStyle(
                                color: Color(0xff68737d),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(
                              color: Color(0xff68737d),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                      reservedSize: 50,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d), width: 1),
                ),
                minX: 0,
                maxX: _monthlySales.length - 1.0,
                minY: 0,
                maxY: _monthlySales.fold<double>(0, (max, item) => 
                    math.max(max, item['revenue'] as double)) * 1.2,
                lineBarsData: [
                  // Revenue Line
                  LineChartBarData(
                    spots: List.generate(_monthlySales.length, (index) {
                      return FlSpot(
                        index.toDouble(), 
                        _monthlySales[index]['revenue'] as double
                      );
                    }),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  // Profit Line
                  LineChartBarData(
                    spots: List.generate(_monthlySales.length, (index) {
                      return FlSpot(
                        index.toDouble(), 
                        _monthlySales[index]['profit'] as double
                      );
                    }),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Revenue', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Profit', Colors.green),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopProductsTab() {
    if (_topProducts.isEmpty) {
      return const Center(child: Text('No product data available'));
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products',
            style: AppConstants.subheadingStyle,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _topProducts.length,
              itemBuilder: (context, index) {
                final product = _topProducts[index];
                final name = product['name'] as String;
                final totalSold = product['total_sold'] as int;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppConstants.primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text('Total Sold: $totalSold'),
                    trailing: SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: index == 0
                            ? 1.0
                            : totalSold / (_topProducts[0]['total_sold'] as int),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.shade400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopClientsTab() {
    if (_topClients.isEmpty) {
      return const Center(child: Text('No client data available'));
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Clients by Revenue',
            style: AppConstants.subheadingStyle,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _topClients.length,
              itemBuilder: (context, index) {
                final client = _topClients[index];
                final name = client['name'] as String;
                final totalSpent = client['total_spent'] as double;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppConstants.primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text('Total Spent: \$${totalSpent.toStringAsFixed(2)}'),
                    trailing: SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: index == 0
                            ? 1.0
                            : totalSpent / (_topClients[0]['total_spent'] as double),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
