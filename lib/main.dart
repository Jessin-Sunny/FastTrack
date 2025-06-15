import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer
import 'package:animated_text_kit/animated_text_kit.dart'; // Import for animated text
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences
import 'screens/guest.dart';
import 'screens/personnel.dart';
import 'dart:math';
import 'screens/forgot_password.dart';
import 'firebase_notifications.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase Initialized');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Initialize local notifications
  var android = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var ios = const DarwinInitializationSettings();
  var initSettings = InitializationSettings(android: android, iOS: ios);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Request permission for notifications
  await requestNotificationPermission();

  runApp(MyApp());
}

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else {
    print('User denied permission');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    FirebaseNotifications.initialize(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // Start with the SplashScreen
    );
  }
}

// Splash Screen Widget
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 4), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PersonnelPage(
              password: '',
            ), // Navigate to PersonnelPage if logged in
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FirstPage(), // Navigate to FirstPage if not logged in
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/Map.jpg'), // Background
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FastTrack Text
                Text(
                  'FastTrack',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),
                // Round Logo with Moving Bike
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fasttrack Logo
                    ClipOval(
                      child: Image.asset(
                        'images/Fasttrack_logo.jpg', // Logo
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Moving Bike Animation
                    AnimatedBike(),
                  ],
                ),
                SizedBox(height: 20),
                TypingEffect(), // Your existing TypingEffect widget
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBike extends StatefulWidget {
  const AnimatedBike({super.key});

  @override
  _AnimatedBikeState createState() => _AnimatedBikeState();
}

class _AnimatedBikeState extends State<AnimatedBike>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4), // Rotation speed
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double radius = 60; // Distance from the center

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double angle = _controller.value * 2 * pi;
        double x = radius * cos(angle);
        double y = radius * sin(angle);

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
            angle: angle + pi / 2, // Adjust bike rotation
            child: Image.asset(
              'images/bike.png', // Replace with bike image
              width: 50,
              height: 50,
            ),
          ),
        );
      },
    );
  }
}

class TypingEffect extends StatelessWidget {
  const TypingEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        fontSize: 20.0,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      child: AnimatedTextKit(
        animatedTexts: [
          TypewriterAnimatedText(
            'Your ultimate delivery guide',
            speed: const Duration(milliseconds: 100), // Adjust speed
          ),
        ],
        totalRepeatCount: 1, // Runs once
      ),
    );
  }
}

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});
  @override
  State<FirstPage> createState() => _FirstPageState();
}

// First Page Widget
class _FirstPageState extends State<FirstPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  bool _obscureText = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    getFCMToken();
    _usernameFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  final String url = "https://flutter.dev";
  void _launchURL() async {
    final Uri url = Uri.parse('https://flutter.dev');

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication, // Ensures it opens in browser
    )) {
      throw 'Could not launch $url';
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: url)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link copied to clipboard!')),
      );
    });
  }

  Future<void> _login() async {
    // Get the username and password from the text fields
    String email = _usernameController.text;
    String password = _passwordController.text;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your email'),
        ),
      );
      return;
    } else if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your password'),
        ),
      );
      return;
    }
    try {
      // Sign in with Firebase Authentication
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signing In...'),
          duration: Duration(milliseconds: 500),
        ),
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save login state
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Navigate to PersonnelPage after successful login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PersonnelPage(password: password),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid Email Address. Please try again.'),
          ),
        );
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wrong password provided.'),
          ),
        );
      } else if (e.code == 'invalid-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid credentials. Please try again.'),
          ),
        );
      } else if (e.code == 'network-request-failed') {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('No Internet Connection'),
              content: Text(
                  'Please turn on your internet connection and try again.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FirstPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Container(
          width: 300,
          height: 550,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: BouncingScrollPhysics(),
                    children: [
                      // Delivery Personnel Login Page
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "DELIVERY PERSONNEL",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "LOGIN",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            cursorColor: Colors.black,
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            decoration: InputDecoration(
                              hintText: "Email",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            cursorColor: Colors.black,
                            obscureText: _obscureText,
                            controller: _passwordController,
                            decoration: InputDecoration(
                              hintText: "Password",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.black,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ForgotPasswordPage()),
                              );
                            },
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 100, vertical: 15),
                              textStyle: TextStyle(fontSize: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "LOGIN",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Swipe right >>>",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      // Guest Page
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "For Continuing as Guest",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to a welcome page for guests
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GuestWelcomePage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.all(20),
                              textStyle: TextStyle(fontSize: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Continue",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1, // Ensure it doesn't wrap
                            ),
                          ),
                          SizedBox(
                              height:
                                  30), // Add some space before the next section
                          Text(
                            "For Company Login",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _launchURL,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors
                                  .green, // You can choose a different color
                              padding: EdgeInsets.all(20),
                              textStyle: TextStyle(fontSize: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Click Here",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1, // Ensure it doesn't wrap
                            ),
                          ),
                          SizedBox(height: 10),
                          // Copy Link Button
                          GestureDetector(
                            onTap: () => _copyToClipboard(context),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Copy Link",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(Icons.copy, color: Colors.blue),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "<<< Swipe left",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Indicator Circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 0 ? Colors.blue : Colors.grey,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 1 ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
