import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isAssignment = true;
  //bool isAppupdates = false;
  //bool isPrivacy = true;
  String selectedLanguage = "English"; // Default language
  String selectedTheme = "Light"; // Default theme
  String selectedUnit = "Kilometers"; // Default unit of measurement

  @override
  void initState() {
    super.initState();
    loadPreferences(); // Load saved settings
  }

  // Load saved settings from SharedPreferences
  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isAssignment = prefs.getBool('isAssignment') ?? true;
      //isAppupdates = prefs.getBool('isAppupdates') ?? false;
      //isPrivacy = prefs.getBool('isPrivacy') ?? true;

      String? theme = prefs.getString('selectedTheme');
      selectedTheme =
          ((theme == "Light" || theme == "Dark") ? theme : "Light")!;

      String? language = prefs.getString('selectedLanguage');
      selectedLanguage = ((language == "English" || language == "Malayalam")
          ? language
          : "English")!;

      String? unit = prefs.getString('selectedUnit');
      selectedUnit =
          ((unit == "Kilometers" || unit == "Miles") ? unit : "Kilometers")!;
    });
  }

  // Save settings to SharedPreferences
  Future<void> savePreference(String key, dynamic value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0), // Adds some spacing
            child: Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        color: Colors.blue,
        height: double.infinity, // Set background color
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(width: 20),
                    Icon(Icons.notifications,
                        color: Colors.white), // White icon
                    SizedBox(width: 10),
                    Text(
                      'Notifications',
                      style: TextStyle(
                          color: Colors.white, // White text
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(width: 20),
                    Icon(
                      Icons.shopping_bag,
                      color: Colors.white,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delivery & Assignment',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18), // White text
                    ),
                    Spacer(), // Pushes switch to the right
                    Switch(
                      value: isAssignment,
                      onChanged: (value) {
                        setState(() {
                          isAssignment = value; // Toggle state
                          savePreference('isAssignment', isAssignment);
                        });
                      },
                      activeColor: Colors.white, // ON color
                      inactiveThumbColor: Colors.grey, // OFF color
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    /*
                    SizedBox(width: 20),
                    Icon(
                      Icons.system_update,
                      color: Colors.white,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'App Updates',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18), // White text
                    ),
                    Spacer(), // Pushes switch to the right
                    
                    Switch(
                      value: isAppupdates,
                      onChanged: (value) {
                        setState(() {
                          isAppupdates = value; // Toggle state
                          savePreference('isAppupdates', isAppupdates);
                        });
                      },
                      activeColor: Colors.white, // ON color
                      inactiveThumbColor: Colors.grey, // OFF color
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(width: 20),
                    Icon(
                      Icons.system_security_update_warning,
                      color: Colors.white,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Privacy & Security',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18), // White text
                    ),
                    Spacer(), // Pushes switch to the right
                    Switch(
                      value: isPrivacy,
                      onChanged: (value) {
                        setState(() {
                          isPrivacy = value; // Toggle state
                          savePreference('isPrivacy', isPrivacy);
                        });
                      },
                      activeColor: Colors.white, // ON color
                      inactiveThumbColor: Colors.grey, // OFF color
                    ),
                    */
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(width: 20),
                    Icon(Icons.settings, color: Colors.white), // White icon
                    SizedBox(width: 10),
                    Text(
                      'General',
                      style: TextStyle(
                          color: Colors.white, // White text
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Language Selection Dropdown
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.language, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Language",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedLanguage,
                        dropdownColor:
                            Colors.blue[800], // Background color of dropdown
                        style: TextStyle(color: Colors.white), // Text color
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: ["English"].map((String language) {
                          return DropdownMenuItem<String>(
                            value: language,
                            child: Text(language,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedLanguage = newValue!;
                            savePreference('selectedLanguage', newValue);
                          });
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10),

                // Theme Selection Dropdown
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.brightness_6, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Theme",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedTheme,
                        dropdownColor: Colors.blue[800],
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: ["Light"].map((String theme) {
                          return DropdownMenuItem<String>(
                            value: theme,
                            child: Text(theme,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedTheme = newValue!;
                            savePreference('selectedTheme', newValue);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                // Units & Measurement Dropdown
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Units & Measurement",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedUnit,
                        dropdownColor: Colors.blue[800],
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: ["Kilometers"].map((String unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedUnit = newValue!;
                            savePreference('selectedUnit', newValue);
                          });
                        },
                      ),
                    ],
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
