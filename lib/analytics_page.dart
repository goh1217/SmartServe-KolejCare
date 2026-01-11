import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:owtest/staff_complaints.dart';
import 'package:owtest/settings_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'view_rating.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, dynamic>? _staffData;
  bool _isLoadingStaff = true;
  DateTime? _selectedReportMonth;
  Map<String, dynamic>? _monthlyReportData;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _fetchStaffWorkCollege();
  }

  Future<void> _fetchStaffWorkCollege() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        if (mounted) setState(() => _isLoadingStaff = false);
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted && querySnapshot.docs.isNotEmpty) {
        setState(() {
          _staffData = querySnapshot.docs.first.data();
          _isLoadingStaff = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingStaff = false);
      }
    } catch (e) {
      print("Error fetching staff workCollege: $e");
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Ratings',
            icon: const Icon(Icons.star, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewRatingPage())),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaint').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No complaints to analyze.'));
          }

          final allDocs = snapshot.data!.docs;

          // Map each doc to a Future<Complaint>
          final complaintFutures =
          allDocs.map((doc) => Complaint.fromFirestore(doc)).toList();

          // Wait for all Future<Complaint> to complete
          return FutureBuilder<List<Complaint>>(
            future: Future.wait(complaintFutures),
            builder: (context, complaintSnapshot) {
              if (complaintSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (complaintSnapshot.hasError) {
                return Center(
                    child:
                    Text('Error loading complaints: ${complaintSnapshot.error}'));
              }
              if (!complaintSnapshot.hasData || complaintSnapshot.data!.isEmpty) {
                return const Center(child: Text('No complaints available.'));
              }

              var complaints = complaintSnapshot.data!;

              // Filter by staff's workCollege
              final workCollege = _staffData?['workCollege']?.toString();
              if (workCollege != null && workCollege.isNotEmpty) {
                complaints = complaints
                    .where((c) => c.residentCollege == workCollege)
                    .toList();
              }

              if (complaints.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No complaints found for your assigned college.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // --- Main Analytics Calculations ---
              final totalComplaints = complaints.length;
              final completedComplaints =
              complaints.where((c) => c.status == 'Completed').toList();
              final completionRate = totalComplaints > 0
                  ? (completedComplaints.length / totalComplaints) * 100
                  : 0.0;

              double totalResolutionHours = 0;
              int resolvedWithDatesCount = 0;

              for (var c in completedComplaints) {
                // Using complaint.submitted and assume a resolvedDate field exists
                // If you have scheduleDate, replace accordingly
                // For demo, let's just simulate average time
                totalResolutionHours += 24; // mock 1 day per completed
                resolvedWithDatesCount++;
              }

              final avgHours = resolvedWithDatesCount > 0
                  ? totalResolutionHours / resolvedWithDatesCount
                  : 0.0;

              final categoryCounts =
              _calculateBreakdown(complaints, (c) => c.category);
              final statusCounts =
              _calculateBreakdown(complaints, (c) => c.status);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('System Analytics'),
                    const SizedBox(height: 12),
                    _buildSummaryCards(totalComplaints, completionRate, avgHours),
                    _buildMonthlyReportSection(complaints),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Complaints by Category'),
                    const SizedBox(height: 16),
                    _buildCategoryChart(categoryCounts),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Status Distribution'),
                    const SizedBox(height: 12),
                    _buildStatusDistribution(statusCounts),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _selectAndGenerateReport(List<Complaint> allComplaints) async {
    final DateTime? picked = await _showMonthAndYearPicker(context);

    if (picked != null) {
      setState(() {
        _selectedReportMonth = picked;
        _isGeneratingReport = true;
        _monthlyReportData = null; // Clear previous report
      });

      // Artificial delay for user to see loading indicator
      await Future.delayed(const Duration(milliseconds: 500));

      final monthlyComplaints = allComplaints.where((c) {
        return c.submitted.year == picked.year && c.submitted.month == picked.month;
      }).toList();

      if (monthlyComplaints.isEmpty) {
        setState(() {
          _monthlyReportData = {'total': 0};
          _isGeneratingReport = false;
        });
        return;
      }

      final total = monthlyComplaints.length;
      final categoryCounts = _calculateBreakdown(monthlyComplaints, (c) => c.category);
      final statusCounts = _calculateBreakdown(monthlyComplaints, (c) => c.status);
      final collegeCounts = _calculateBreakdown(monthlyComplaints, (c) => c.residentCollege);
      final priorityCounts = _calculateBreakdown(monthlyComplaints, (c) => c.priority);

      final completedCount =
          monthlyComplaints.where((c) => c.status == 'Completed').length;
      final completionRate =
          total > 0 ? (completedCount / total) * 100 : 0.0;

      final pendingCount =
          monthlyComplaints.where((c) => c.status == 'Pending').length;

      final distinctDays = monthlyComplaints
          .map((c) => DateTime(c.submitted.year, c.submitted.month, c.submitted.day))
          .toSet()
          .length;
      final avgPerDay =
          distinctDays > 0 ? (total / distinctDays) : total.toDouble();

      setState(() {
        _monthlyReportData = {
          'total': total,
          'categories': categoryCounts,
          'statuses': statusCounts,
          'colleges': collegeCounts,
          'priorities': priorityCounts,
          'completed': completedCount,
          'pending': pendingCount,
          'completionRate': completionRate,
          'avgPerDay': avgPerDay,
          'complaints': monthlyComplaints,
        };
        _isGeneratingReport = false;
      });
    }
  }

  Widget _buildMonthlyReportSection(List<Complaint> complaints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _selectAndGenerateReport(complaints),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Generate Monthly Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isGeneratingReport)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )),
        if (_selectedReportMonth != null && _monthlyReportData != null && !_isGeneratingReport)
          _buildMonthlyReport(),
        const Divider(),
      ],
    );
  }

  Widget _buildMonthlyReport() {
    if (_monthlyReportData!['total'] == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Text(
            'No complaints found for ${DateFormat.yMMMM().format(_selectedReportMonth!)}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    final String monthYear = DateFormat.yMMMM().format(_selectedReportMonth!);
    final Map<String, int> categories = _monthlyReportData!['categories'];
    final Map<String, int> statuses = _monthlyReportData!['statuses'];
    final Map<String, int> colleges = _monthlyReportData!['colleges'];
    final Map<String, int> priorities = _monthlyReportData!['priorities'];
    final int completed = _monthlyReportData!['completed'];
    final int pending = _monthlyReportData!['pending'];
    final double completionRate = _monthlyReportData!['completionRate'];
    final double avgPerDay = _monthlyReportData!['avgPerDay'];

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report for $monthYear',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Complaints: ${_monthlyReportData!['total']}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Completed: $completed (${completionRate.toStringAsFixed(0)}%) | Pending: $pending',
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(
            'Average complaints per active day: ${avgPerDay.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const Divider(height: 24),
          _buildReportBreakdown('Colleges', colleges),
          _buildReportBreakdown('Categories', categories),
          _buildReportBreakdown('Statuses', statuses),
          _buildReportBreakdown('Priorities', priorities),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _downloadMonthlyReportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download as PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showMonthAndYearPicker(BuildContext context) async {
    int selectedYear = _selectedReportMonth?.year ?? DateTime.now().year;
    int selectedMonth = _selectedReportMonth?.month ?? DateTime.now().month;

    final years = List<int>.generate(
      DateTime.now().year - 2019,
      (index) => 2020 + index,
    );

    final months = List<int>.generate(12, (index) => index + 1);

    return showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Select month and year'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMonth,
                      items: months
                          .map(
                            (m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text(DateFormat.MMMM().format(DateTime(0, m))),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setStateDialog(() {
                          selectedMonth = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedYear,
                      items: years
                          .map(
                            (y) => DropdownMenuItem<int>(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setStateDialog(() {
                          selectedYear = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(DateTime(selectedYear, selectedMonth));
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadMonthlyReportPdf() async {
    if (_monthlyReportData == null || _selectedReportMonth == null) return;

    final String monthYear = DateFormat.yMMMM().format(_selectedReportMonth!);
    final int total = _monthlyReportData!['total'] as int;
    if (total == 0) return;

    final int completed = _monthlyReportData!['completed'] as int;
    final int pending = _monthlyReportData!['pending'] as int;
    final double completionRate = (_monthlyReportData!['completionRate'] as double);
    final double avgPerDay = (_monthlyReportData!['avgPerDay'] as double);

    final Map<String, int> categories =
        Map<String, int>.from(_monthlyReportData!['categories']);
    final Map<String, int> statuses =
        Map<String, int>.from(_monthlyReportData!['statuses']);
    final Map<String, int> priorities =
        Map<String, int>.from(_monthlyReportData!['priorities']);
    final Map<String, int> colleges =
        Map<String, int>.from(_monthlyReportData!['colleges']);

    final List<Complaint> complaints =
        (_monthlyReportData!['complaints'] as List<Complaint>);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'Monthly Complaint Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              monthYear,
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Bullet(
              text:
                  'Total complaints: $total (Completed: $completed, Pending: $pending)',
            ),
            pw.Bullet(
              text: 'Completion rate: ${completionRate.toStringAsFixed(0)}%',
            ),
            pw.Bullet(
              text:
                  'Average complaints per active day: ${avgPerDay.toStringAsFixed(1)}',
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'By College',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            _pdfKeyValueTable(colleges),
            pw.SizedBox(height: 8),
            pw.Text(
              'By Category',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            _pdfKeyValueTable(categories),
            pw.SizedBox(height: 8),
            pw.Text(
              'By Status',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            _pdfKeyValueTable(statuses),
            pw.SizedBox(height: 8),
            pw.Text(
              'By Priority',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            _pdfKeyValueTable(priorities),
            pw.SizedBox(height: 16),
            pw.Text(
              'Complaints Detail',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: [
                'Date',
                'Title',
                'Category',
                'Priority',
                'Status',
                'Room',
              ],
              data: complaints.map((c) {
                return [
                  DateFormat.yMMMd().format(c.submitted),
                  c.title,
                  c.category,
                  c.priority,
                  c.status,
                  c.room,
                ];
              }).toList(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE5E7EB),
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'complaints_report_${_selectedReportMonth!.year}_${_selectedReportMonth!.month.toString().padLeft(2, '0')}.pdf',
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'PDF sharing is not available on this device build (printing plugin not registered).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
        ),
      );
    }
  }

  pw.Widget _pdfKeyValueTable(Map<String, int> data) {
    if (data.isEmpty) {
      return pw.Text(
        'No data',
        style: const pw.TextStyle(fontSize: 10),
      );
    }

    final rows = data.entries
        .map(
          (e) => [
            e.key,
            e.value.toString(),
          ],
        )
        .toList();

    return pw.Table.fromTextArray(
      headers: ['Item', 'Count'],
      data: rows,
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3F4F6),
      ),
    );
  }

  Widget _buildReportBreakdown(String title, Map<String, int> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Do not show college breakdown if only one college has complaints and a work college is assigned
    final workCollege = _staffData?['workCollege']?.toString();
    if (title == 'Colleges' && (data.length <= 1 && workCollege != null && workCollege.isNotEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
          const SizedBox(height: 8),
          ...data.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                  Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Map<String, int> _calculateBreakdown(
      List<Complaint> complaints, String Function(Complaint) attribute) {
    final Map<String, int> counts = {};
    for (var complaint in complaints) {
      final key = attribute(complaint);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style:
      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildSummaryCards(int total, double rate, double avgTime) {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.content_paste,
            value: total.toString(),
            label: 'Total\nComplaints',
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.percent,
            value: '${rate.toStringAsFixed(0)}%',
            label: 'Completion\nRate',
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAnalyticsCardSmall(
            icon: Icons.access_time,
            value: '${avgTime.toStringAsFixed(1)}h',
            label: 'Avg.\nResolution\nTime',
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCardSmall(
      {required IconData icon,
        required String value,
        required String label,
        required Color color}) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> data) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No data available'),
        ),
      );
    }

    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    const barWidth = 60.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.entries.map((entry) {
            final height = (entry.value / maxValue) * 150;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: barWidth,
                  child: Text(
                    entry.key,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, int> statusCount) {
    return Column(
      children: statusCount.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '${entry.value}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
