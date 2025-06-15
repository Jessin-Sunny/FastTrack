import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  final String personnelId;
  const NotificationsPage({super.key, required this.personnelId});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    List<Map<String, dynamic>> notifications = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("Notification")
          .doc("Vwhs2MsdW9ZCJYE4ooqz") // Replace with actual campaign ID
          .collection("DeliveryPersonnels")
          .doc(widget.personnelId)
          .collection("Assignment")
          .orderBy("time", descending: true)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Convert timestamp to readable time
        String timeAgo = formatTimeAgo(data['time']);

        notifications.add({
          "id": doc.id,
          "title": data["title"] ?? "No Title",
          "body": data["body"] ?? "No Message",
          "time": timeAgo,
          "read": data["read"] ?? false,
        });
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }
    /*
    DatabaseReference notificationRef = FirebaseDatabase.instance.ref("Notification/Vwhs2MsdW9ZCJYE4ooqz/DeliveryPersonnels/FD2B3108/Assignment");

notificationRef.onChildAdded.listen((event) {
  if (event.snapshot.exists) {
    Map<String, dynamic> notificationData = Map<String, dynamic>.from(event.snapshot.value as Map);
    
    String title = notificationData['title'];
    String body = notificationData['body'];

    // Trigger local notification
    showLocalNotification(title, body);
  }
});
    */

    return notifications;
  }

  String formatTimeAgo(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    Duration difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hr ago";
    } else {
      return DateFormat('MMM d, yyyy').format(date); // e.g., Mar 8, 2025
    }
  }
  /*
  List<Map<String, dynamic>> notifications = [
    {
      "title": "Package Scanned",
      "body": "Order FPA22017 has been scanned by you.",
      "time": "5 min ago",
      "read": false
    },
    {
      "title": "Package Scanned",
      "body": "Order FPA22019 has been scanned by you.",
      "time": "5 min ago",
      "read": false
    },
    {
      "title": "Package Scanned",
      "body": "Order FPA22045 has been scanned by you.",
      "time": "5 min ago",
      "read": false
    },
    {
      "title": "Package Scanned",
      "body": "Order FPA22389 has been scanned by you.",
      "time": "5 min ago",
      "read": false
    },
    {
      "title": "Package Scanned",
      "body": "Order FPA22456 has been scanned by you.",
      "time": "5 min ago",
      "read": false
    },
    {
      "title": "New Package Assigned",
      "body": "Order FPA22017 has been assigned to you.",
      "time": "1 hr ago",
      "read": false
    },
    {
      "title": "New Package Assigned",
      "body": "Order FPA22019 has been assigned to you.",
      "time": "1 hr ago",
      "read": false
    },
    {
      "title": "New Package Assigned",
      "body": "Order FPA22045 has been assigned to you.",
      "time": "1 hr ago",
      "read": false
    },
    {
      "title": "New Package Assigned",
      "body": "Order FPA22389 has been assigned to you.",
      "time": "1 hr ago",
      "read": false
    },
    {
      "title": "New Package Assigned",
      "body": "Order FPA22456 has been assigned to you.",
      "time": "1 hr ago",
      "read": false
    },
  ];

  void markAsRead(int index) {
    setState(() {
      notifications[index]['read'] = true;
    });
  }
*/

  Future<void> markAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection("Notification")
          .doc("Vwhs2MsdW9ZCJYE4ooqz")
          .collection("DeliveryPersonnels")
          .doc(widget.personnelId)
          .collection("Assignment")
          .doc(docId)
          .update({"read": true});

      setState(() {}); // Refresh UI
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  void deleteNotification(String notificationId) async {
    String notificationDocId = "Vwhs2MsdW9ZCJYE4ooqz"; // Adjust if needed
    String personnelId = "FD2B3108"; // Get dynamically if required

    try {
      await FirebaseFirestore.instance
          .collection("Notification")
          .doc(notificationDocId)
          .collection("DeliveryPersonnels")
          .doc(widget.personnelId)
          .collection("Assignment")
          .doc(notificationId)
          .delete();

      print("Notification deleted: $notificationId");
    } catch (e) {
      print("Error deleting notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications"));
          }

          List<Map<String, dynamic>> notifications = snapshot.data ?? [];

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notification = notifications[index];

              return Dismissible(
                key: Key(notification['id']), // Unique key for each item
                direction:
                    DismissDirection.endToStart, // Swipe from right to left
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  deleteNotification(notification['id']);
                  setState(() {
                    notifications.removeAt(index);
                  });
                },
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      notification['read']
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: notification['read'] ? Colors.grey : Colors.blue,
                    ),
                    title: Text(notification['title'],
                        style: TextStyle(
                            fontWeight: notification['read']
                                ? FontWeight.normal
                                : FontWeight.bold)),
                    subtitle: Text(notification['body']),
                    trailing: Text(notification['time'],
                        style: const TextStyle(color: Colors.grey)),
                    onTap: () {
                      if (!notification['read']) {
                        markAsRead(notification['id']);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
