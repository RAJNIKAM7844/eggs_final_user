import 'package:EggPort/home_page.dart';
import 'package:EggPort/login_page.dart';
import 'package:EggPort/reset_page.dart';
import 'package:EggPort/sign_up.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Replace these with your actual page imports

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://kwoxhpztkxzqetwanlxx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3b3hocHp0a3h6cWV0d2FubHh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxMjQyMTAsImV4cCI6MjA2MDcwMDIxMH0.jEIMSnX6-uEA07gjnQKdEXO20Zlpw4XPybfeLQr7W-M',
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter error: ${details.exceptionAsString()}');
    print(details.stack);
  };

  final prefs = await SharedPreferences.getInstance();
  final supabase = Supabase.instance.client;
  final isLoggedIn = supabase.auth.currentSession != null;

  // If user is logged in, mark onboarding as seen
  if (isLoggedIn) {
    await prefs.setBool('hasSeenOnboarding', true);
  }

  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  runApp(MyApp(
    hasSeenOnboarding: hasSeenOnboarding,
    isLoggedIn: isLoggedIn,
  ));
}

// Slide Transition Function
Route createSlideTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // Slide from right
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class MyApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.isLoggedIn,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');
    if (uri.path.contains('reset-password')) {
      final token = uri.queryParameters['token'];
      print('Token: $token');
      if (token != null) {
        Navigator.pushNamed(
          context,
          '/complete-reset',
          arguments: {'token': token},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid reset link')),
        );
      }
    } else {
      print('Deep link path does not match: ${uri.path}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "HMS Egg Distributions",
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.blue,
      ),
      initialRoute: widget.hasSeenOnboarding
          ? (widget.isLoggedIn ? '/home' : '/login')
          : '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const PageOne();
            break;
          case '/page-two':
            page = const PageTwo();
            break;
          case '/page-three':
            page = const PageThree();
            break;
          case '/page-four':
            page = const PageFour();
            break;
          case '/login':
            page = const LoginPage();
            break;
          case '/signup':
            page = const SignUpPage();
            break;
          case '/home':
            page = const HomePage();
            break;
          case '/reset':
            page = const ResetPasswordPage();
            break;

          default:
            page = const PageOne();
        }
        return createSlideTransition(page);
      },
    );
  }
}

// Page 1 - Rolling Egg Animation
class PageOne extends StatefulWidget {
  const PageOne({super.key});

  @override
  _PageOneState createState() => _PageOneState();
}

class _PageOneState extends State<PageOne> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);
    _translateAnimation = Tween<double>(
      begin: -150.0,
      end: 150.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button from exiting
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacementNamed(context, '/page-two');
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_translateAnimation.value, 0),
                      child: Transform.rotate(
                        angle: _rotateAnimation.value,
                        child: Image.asset('assets/egg.png', width: 150),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                const Text(
                  "HMS EGG DISTRIBUTIONS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/page-two');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Page 2 - Stacked Eggs Design
class PageTwo extends StatelessWidget {
  const PageTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button from going back
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color.fromARGB(255, 51, 51, 51),
                  width: 3,
                ),
              ),
              child: Image.asset('assets/image2.png', fit: BoxFit.cover),
            ),
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                "Welcome to HMS EGG DISTRIBUTORS",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "At HMS, we deliver only the finest quality eggs with a strong commitment to excellence and customer satisfaction.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/page-three');
              },
              child: const Text("CONTINUE"),
            ),
          ],
        ),
      ),
    );
  }
}

// Page 3 - Egg on Forks Design
class PageThree extends StatelessWidget {
  const PageThree({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button from going back
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              child: Image.asset('assets/image3.png', fit: BoxFit.cover),
            ),
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                "Trusted & Nutritious Eggs",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "We ensure freshness, hygiene, and nutritional value with every egg we deliver. Choose from a wide range of organic, free-range, and specialty eggs!",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/page-four');
              },
              child: const Text("CONTINUE"),
            ),
          ],
        ),
      ),
    );
  }
}

// Page 4 - Final Page with CTA
class PageFour extends StatelessWidget {
  const PageFour({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    // Clear the entire navigation stack and go to login
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button from going back
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              child: Image.asset('assets/image4.png', fit: BoxFit.cover),
            ),
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                "Why Choose HMS?",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "• Fast Delivery\n• Affordable Pricing\n• 100% Fresh Eggs\n• Trusted by 500+ customers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _completeOnboarding(context),
              child: const Text("GET STARTED"),
            ),
          ],
        ),
      ),
    );
  }
}
