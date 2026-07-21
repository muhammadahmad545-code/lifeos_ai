import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LifeOSShell extends StatelessWidget {
  const LifeOSShell({super.key, required this.child});

  final Widget child;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(path: '/home', label: 'Home', icon: Icons.home_rounded),
    _NavItem(path: '/tasks', label: 'Tasks', icon: Icons.check_circle_outline_rounded),
    _NavItem(path: '/notes', label: 'Notes', icon: Icons.sticky_note_2_outlined),
    _NavItem(path: '/assistant', label: 'AI', icon: Icons.auto_awesome_rounded),
    _NavItem(path: '/settings', label: 'More', icon: Icons.grid_view_rounded),
  ];

  int _indexForLocation(String location) {
    final int index = _items.indexWhere((item) => location.startsWith(item.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final int currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) => context.go(_items[index].path),
        destinations: _items
            .map(
              (_NavItem item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}
