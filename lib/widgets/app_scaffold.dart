// lib/widgets/app_scaffold.dart
import 'package:flutter/material.dart';
import '../common/responsive_layout.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int currentIndex;
  final void Function(int) onIndexChanged;

  const AppScaffold({
    required this.title,
    required this.body,
    required this.currentIndex,
    required this.onIndexChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
      ),
      body: Row(
        children: [
          if (ResponsiveLayout.isDesktop(context))
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onIndexChanged,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.search), label: Text('Search')),
                NavigationRailDestination(icon: Icon(Icons.add), label: Text('Add Lead')),
                NavigationRailDestination(icon: Icon(Icons.list), label: Text('All Leads')),
              ],
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: ResponsiveLayout.isDesktop(context)
          ? null
          : BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onIndexChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add Lead'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'All Leads'),
        ],
      ),
    );
  }
}
