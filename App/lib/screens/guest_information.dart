import 'package:flutter/material.dart';
import 'support.dart';

class GuestInformation extends StatelessWidget {
  const GuestInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FastTrack'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help,
                        size: 70,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'How to use FastTrack?',
                        style: TextStyle(fontSize: 20),
                      ),
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment(-0.7, 0.0),
                        child: Text(
                          '1. How to input a location ? ',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal, // Enables horizontal scrolling
                          child: Row(
                            children: [
                              SizedBox(width: 30),
                              Image.asset(
                                'images/instr2.jpg',
                                width: 250, // Adjusted width
                                height: 550, // Adjusted height
                              ),
                              SizedBox(width: 20), // Spacing between images
                              Image.asset(
                                'images/instr3.jpg',
                                width: 250,
                                height: 550,
                              ),
                              SizedBox(width: 20),
                              Image.asset(
                                'images/instr5.jpg',
                                width: 250,
                                height: 550,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment(-0.7, 0.0),
                        child: Text(
                          '2. How to remove a location ? ',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Row(children: [
                        SizedBox(width: 30),
                        Image.asset(
                          'images/instr8.jpg',
                          width: 250,
                          height: 550,
                        ),
                      ]),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment(-0.5, 0.0),
                        child: Text(
                          '3. How to view current location ? \n    Type "Current Location" to input it',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal, // Enables horizontal scrolling
                          child: Row(
                            children: [
                              SizedBox(width: 30),
                              Image.asset(
                                'images/instr1.jpg',
                                width: 250, // Adjusted width
                                height: 550, // Adjusted height
                              ),
                              SizedBox(width: 20), // Spacing between images
                              Image.asset(
                                'images/instr12.jpg',
                                width: 250,
                                height: 550,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment(-0.1, 0.0),
                        child: Text(
                          '4. How to get a draggable marker ?\n    Type "Marker" to get a draggable Marker',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Row(children: [
                        SizedBox(width: 30),
                        Image.asset(
                          'images/instr11.jpg',
                          width: 250,
                          height: 550,
                        ),
                      ]),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment(-0.5, 0.0),
                        child: Text(
                          '5. How to get optimized route ? ',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal, // Enables horizontal scrolling
                          child: Row(
                            children: [
                              SizedBox(width: 30),
                              Image.asset(
                                'images/instr10.jpg',
                                width: 250, // Adjusted width
                                height: 550, // Adjusted height
                              ),
                              SizedBox(width: 20), // Spacing between images
                              Image.asset(
                                'images/instr6.jpg',
                                width: 250,
                                height: 550,
                              ),
                              SizedBox(width: 20),
                              Image.asset(
                                'images/instr9.jpg',
                                width: 250,
                                height: 550,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      Align(
                        alignment: Alignment(-0.5, 0.0),
                        child: Text(
                          'Need More Help?',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(width: 70),
                          SizedBox(
                            width: 100,
                            height: 50,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Support(),
                                  ),
                                );
                              },
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50)),
                              child: Text("Support"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
