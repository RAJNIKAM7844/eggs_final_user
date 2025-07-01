import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemNavigator
import 'package:EggPort/about.dart';
import 'package:EggPort/contact.dart';
import 'package:EggPort/first.dart';
import 'package:EggPort/profile.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  final int initialIndex;
  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  final List<Widget> _screens = const [
    FirstPage(),
    ContactUsScreen(),
    AboutPage(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_){
      Permission.notification.request();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      // If not on the Home tab (FirstPage), switch to it
      setState(() {
        _selectedIndex = 0; // Switch to FirstPage
      });
      return false; // Prevent popping the route
    }
    // On FirstPage, exit the app
    SystemNavigator.pop();
    return false; // Prevent default pop behavior
  }

  Widget _buildNavItem(IconData iconData, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final size = MediaQuery.of(context).size;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    // Even tighter responsive sizing
    final double iconSize = (size.width * 0.045).clamp(14.0, 22.0);
    final double fontSize =
        (size.width * 0.025 / textScaleFactor).clamp(7.0, 11.0);
    final double padding = (size.width * 0.01).clamp(3.0, 6.0);

    return Flexible(
      fit: FlexFit.tight,
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0288D1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                iconData,
                size: iconSize,
                color: isSelected ? Colors.white : const Color(0xFF757575),
              ),
              SizedBox(height: size.height * 0.002),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  color: isSelected ? Colors.white : const Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isLandscape = size.width > size.height;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _screens[_selectedIndex],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: (size.width * 0.01).clamp(3.0, 5.0),
              color: Colors.white,
              elevation: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double barHeight =
                      isLandscape ? size.height * 0.1 : size.height * 0.06;
                  return SizedBox(
                    height: barHeight.clamp(48.0, 65.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildNavItem(Icons.home_outlined, 'Home', 0),
                        _buildNavItem(Icons.info_outline, 'About', 2),
                        _buildNavItem(Icons.people_outline, 'Contact', 1),
                        _buildNavItem(Icons.person_outline, 'Profile', 3),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
