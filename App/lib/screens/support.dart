import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Support extends StatelessWidget {
  const Support({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0), // Adds some spacing
            child: Icon(Icons.support_agent, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 150, color: Colors.black),
            SizedBox(height: 20),
            Text('Hello, How can we help you?', style: TextStyle(fontSize: 20)),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email, size: 50, color: Colors.red),
                SizedBox(width: 20), // Increased space between icon and button
                ElevatedButton(
                  onPressed: () {
                    final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path:
                            'fasttrack.serviceteam@gmail.com', // Replace with your email address
                        queryParameters: {'subject': 'Support'});
                    launchUrl(emailLaunchUri);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Send us an Email',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 50, color: Colors.green),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    final Uri phoneLaunchUri = Uri(
                        scheme: 'tel',
                        path:
                            '+919782291825'); // Replace with your phone number
                    launchUrl(phoneLaunchUri);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text('Call us', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat, size: 50, color: Colors.blue),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'This feature is under development...Thank you for your patience')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child:
                      Text('Live Chat', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
