// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'pages/search_page.dart';
import 'pages/add_lead_page.dart';
import 'pages/all_leads_page.dart';
import 'widgets/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme();
    return MaterialApp(
      title: 'Mini CRM',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        textTheme: textTheme,
        useMaterial3: false,
      ),
      home: const MainRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainRouter extends StatefulWidget {
  const MainRouter({super.key});
  @override
  State<MainRouter> createState() => _MainRouterState();
}

class _MainRouterState extends State<MainRouter> {
  int _index = 0;
  static const pages = [SearchPage(), AddLeadPage(), AllLeadsPage()];
  static const pageTitles = ['Search', 'Add Lead', 'All Leads'];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: pageTitles[_index],
      currentIndex: _index,
      onIndexChanged: (i) => setState(() => _index = i),
      body: pages[_index],
    );
  }
}
