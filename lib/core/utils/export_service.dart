import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  Future<void> exportToCsv(int currentSteps, double calories, double distance) async {
    final String csvData = 'Date,Steps,Calories,Distance(km)\n'
        '${DateTime.now().toIso8601String().split('T').first},$currentSteps,$calories,$distance\n';

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/step_report.csv');

    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(file.path)], text: 'My Daily Step Report');
  }

  Future<void> exportToPdf(int currentSteps, double calories, double distance) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Build Up - Activity Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${DateTime.now().toIso8601String().split('T').first}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Metric', 'Value'],
                  <String>['Total Steps', currentSteps.toString()],
                  <String>['Calories Burned', '${calories.toStringAsFixed(1)} kcal'],
                  <String>['Distance Covered', '${distance.toStringAsFixed(2)} km'],
                ],
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/step_report.pdf');

    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'My Daily Step Report');
  }
}