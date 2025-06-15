import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class EditProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final String vehicleNo;
  final String capacity;
  final String phoneNo;
  final String password;
  final String profileurl;

  const EditProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.vehicleNo,
    required this.capacity,
    required this.phoneNo,
    required this.password,
    required this.profileurl,
  });
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String email = '';
  String vehicleNo = '';
  String capacity = '';
  String name = '';
  String phoneno = '';
  String password = '';
  String disp_password = '';
  String profileurl = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userEmail = user.email!;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('DeliveryPersonnel')
          .where('D_Email', isEqualTo: userEmail)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        setState(() {
          name = userDoc['D_Name'];
          email = userDoc['D_Email'];
          vehicleNo = userDoc['VehicleNo'];
          capacity = userDoc['Capacity'].toString();
          phoneno = userDoc['D_PhoneNo'];
          password = userDoc['D_Password'];
          profileurl = userDoc['D_Profileurl'];
          disp_password = password[0] +
              '*' * (password.length - 2) +
              password[password.length - 1];
        });
      }
    }
  }

  Future<void> _updateUserPassword() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userEmail = user.email!;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('DeliveryPersonnel')
          .where('D_Email', isEqualTo: userEmail)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        await userDoc.reference.update({
          'D_Password': password,
        });
      }
    }
  }

  void _changePassword(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool obscureText = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      hintText: "Current Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Background color
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (currentPasswordController.text == '') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Please enter your password')));
                          } else if (currentPasswordController.text !=
                              password) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Passwords do not match')));
                          } else {
                            Navigator.of(context).pop();
                            _showNewPasswordDialog(
                                context,
                                newPasswordController,
                                confirmPasswordController);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Background color
                        ),
                        child: Text(
                          'Next',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNewPasswordDialog(
      BuildContext context,
      TextEditingController newPasswordController,
      TextEditingController confirmPasswordController) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool obscureText = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      hintText: "New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Background color
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (newPasswordController.text == '') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Please enter new password')));
                          } else if (newPasswordController.text == password) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'New password must be different from current password')));
                          } else if (newPasswordController.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Password must be at least 6 characters')));
                          } else if (confirmPasswordController.text == '') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Please confirm your password')));
                          } else if (newPasswordController.text ==
                              confirmPasswordController.text) {
                            User? user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              try {
                                UserCredential userCredential =
                                    await FirebaseAuth.instance
                                        .signInWithEmailAndPassword(
                                  email: email,
                                  password: password,
                                );
                                await user
                                    .updatePassword(newPasswordController.text);
                                password = newPasswordController.text;
                                _updateUserPassword();

                                disp_password = password[0] +
                                    '*' * (password.length - 2) +
                                    password[password.length - 1];

                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Password changed successfully')));
                              } catch (e) {
                                //print(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error: Please try again later')));
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Passwords do not match')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Background color
                        ),
                        child:
                            Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBox(String label, String value, {Widget? trailing}) {
    return Container(
      padding: EdgeInsets.all(15.0),
      //margin: EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 18),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0), // Adds some spacing
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true, // Allows tapping outside to close
                    builder: (context) {
                      return Stack(
                        children: [
                          // Blurred Background
                          Positioned.fill(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: 10, sigmaY: 10), // Strong blur
                              child: Container(
                                  color: Colors.black.withOpacity(0.5)),
                            ),
                          ),
                          // Enlarged Profile Picture
                          Center(
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pop(context), // Close on tap
                              child: InteractiveViewer(
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10), // Smooth edges
                                  child: profileurl.isNotEmpty
                                      ? Image.network(
                                          profileurl,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: profileurl.isNotEmpty
                          ? NetworkImage(
                              profileurl) // Correct way to use network image
                          : null, // No background image if profile URL is empty
                      child: profileurl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            )
                          : null, // Avoid overlapping the image when profile exists
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          print("Edit photo tapped!");
                          // You can add logic for editing here
                        },
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.edit,
                            size: 15,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildDetailBox('Name', name),
              _buildDetailBox('Phone No', phoneno),
              _buildDetailBox('Email', email),
              _buildDetailBox('Vehicle No', vehicleNo),
              _buildDetailBox('Capacity', capacity),
              _buildDetailBox(
                'Password',
                disp_password,
                trailing: IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    _changePassword(context);
                  },
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Background color
                      minimumSize: Size(150, 50),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      //await _updateUserData();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Background color
                      minimumSize: Size(150, 50),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
