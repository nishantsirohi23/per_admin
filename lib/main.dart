import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:peradmin/take_payment.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  _requestStoragePermission();
  runApp(MyApp());
}


Future<void> _requestStoragePermission() async {
  await Permission.storage.request();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WorkDetailsScreen(),
    );
  }
}

class WorkDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work Details'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('work')
            .orderBy('created_at', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          var works = snapshot.data!.docs;

          return ListView.builder(
            itemCount: works.length,
            itemBuilder: (context, index) {
              var work = works[index];
              return ListTile(
                title: Text(work['name'] ?? 'No Name'),
                subtitle: Text(work['description'] ?? 'No Description'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkDetailPage(work: work),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class WorkDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot work;

  WorkDetailPage({required this.work});
  Future<void> _addNote(String note) async {
    try {
      await FirebaseFirestore.instance
          .collection('work')
          .doc(work.id)
          .collection('notes')
          .add({'note': note, 'timestamp': Timestamp.now()});
      // Show success message or update UI as needed
    } catch (e) {
      // Handle error
      print('Error adding note: $e');
    }
  }

  // Function to retrieve notes from Firestore
  Stream<List<QueryDocumentSnapshot>> _getNotesStream() {
    return FirebaseFirestore.instance
        .collection('work')
        .doc(work.id)
        .collection('notes')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> _deleteWork(BuildContext context,String workBy) async {
    String workId = work.id;

    try {
      await FirebaseFirestore.instance.collection('work').doc(workId).delete();
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      if (workBy != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(workBy)
            .collection('tracks')
            .doc(workId)
            .delete();
      }
      QuerySnapshot querySnapshot = await _firestore.collection('users').doc(workBy)
          .collection('work') // Replace with your collection name
          .where('id', isEqualTo: workId)
          .get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        await _firestore.collection('users').doc(workBy).collection('work').doc(doc.id).delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Work and related track deleted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting work: $e')),
      );
    }
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    Clipboard.setData(ClipboardData(text: url));


  }
  void launchWhatsApp({required String phone, required String message}) async {
    final Uri _url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeFull(message)}");

    if (await canLaunchUrl(_url)) {
      await launchUrl(_url);
    } else {
      throw 'Could not launch $_url';
    }
  }
  String? getFieldValue(String fieldName) {
    final data = work.data() as Map<String, dynamic>?;
    return data != null && data.containsKey(fieldName) ? data[fieldName].toString() : 'N/A';
  }

  double? getFieldDoubleValue(String fieldName) {
    final data = work.data() as Map<String, dynamic>?;
    return data != null && data.containsKey(fieldName) ? (data[fieldName] as num).toDouble() : null;
  }

  bool? getFieldBoolValue(String fieldName) {
    final data = work.data() as Map<String, dynamic>?;
    return data != null && data.containsKey(fieldName) ? data[fieldName] as bool : null;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    TextEditingController noteController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(getFieldValue('name') ?? 'No Name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  border: Border.all(color: Colors.pink,width: 1)
              ),
              child: Column(
                children: [
                  Text('Amount: ${getFieldValue('amount')}',style: TextStyle(
                      color: Colors.black,
                      fontSize: 17
                  ),),
                  Text('Final Amount: ${getFieldValue('finalamount')}',style: TextStyle(
                      color: Colors.black,
                      fontSize: 17
                  )),
                  Text('Grand Total: ${getFieldValue('grandtotal')}',style: TextStyle(
                      color: Colors.black,
                      fontSize: 17
                  )),
                ],
              ),
            ),
            SizedBox(height: 7,),

            Text("Workers Applied",style: TextStyle(
                color: Colors.pink,
                fontSize: 19
            ),),
            Container(
              width:screenWidth,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('work').doc(getFieldValue('id')).collection('workers').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {


                    return Visibility(visible: false,child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {


                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {


                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.pink,width: 1),
                          borderRadius: BorderRadius.all(Radius.circular(12))

                      ),
                      padding: EdgeInsets.all(7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text('Currently no worker applied',style: TextStyle(color: Colors.black,fontSize: 16),),
                              Text('for this work Please Wait!',style: TextStyle(color: Colors.black,fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }


                  // Worker collection processing
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> workers = snapshot.data!.docs;
                  // Process workers here
                  return Container(
                    height: 190,
                    // Adjust width based on your requirement
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: workers.length,
                      itemBuilder: (context, index) {
                        // Access each worker document
                        Map<String, dynamic> workerData = workers[index].data();
                        // Process worker details here
                        String workerId = workerData['workerID'] ?? '';
                        double workerAmount = workerData['amount'] ?? '';
                        double workerAmountcut = workerData['workeram'] ?? '';

                        String workerAmounts = workerAmount.toString();
                        // Return a FutureBuilder to get user details based on workerId
                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance.collection('prof').doc(workerId).get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {


                              return Visibility(visible: false,child: CircularProgressIndicator());
                            } else if (userSnapshot.hasError) {

                              return Text('Error: ${userSnapshot.error}');
                            } else if (!userSnapshot.hasData || !userSnapshot.data!.exists) {


                              return Text('User not found 2');
                            }


                            // Access user data and display details
                            Map<String, dynamic> userData = userSnapshot.data!.data()!;
                            String userName = userData['name'] ?? '';
                            String phone_number = userData['phone_number'] ?? '';
                            String profile_image_url = userData['profile_image_url'] ?? '';


                            String userRole = userData['email'] ?? '';
                            final List<dynamic> listspecs = userData['specs'] ?? [];
                            print(userData);

                            // Display worker information

                            return Container(
                              height: 150,
                              width: screenWidth*0.6,
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(top: 12, bottom: 10, right: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(30.0),
                                color: Colors.transparent,

                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    child: Column(
                                      children: [
                                        Container(
                                          child: Text(
                                            userData['name'],
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                              fontSize: screenWidth*0.05,
                                              overflow: TextOverflow.ellipsis, // or TextOverflow.ellipsis, etc.
                                            ),
                                          ),
                                        ),

                                        Container(
                                          child: Text(
                                            userData['phone_number'],
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                              fontSize: screenWidth*0.05,
                                              overflow: TextOverflow.ellipsis, // or TextOverflow.ellipsis, etc.
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.only(left: 10,right: 10,top: 3,bottom: 3),
                                              child: Text(workerAmount.toString()),
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.pink,width: 1)
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.only(left: 10,right: 10,top: 3,bottom: 3),
                                              child: Text(workerAmountcut.toString()),
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.pink,width: 1)
                                              ),
                                            ),
                                          ],
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            print("usernumber from direction screen");
                                            print(userData['mobile']);
                                            FlutterPhoneDirectCaller.callNumber(userData['mobile']);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.pink),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.call,
                                            color: Colors.pink,
                                          ),
                                          label: Text(
                                            'Call',
                                            style: TextStyle(
                                              color: Colors.pink,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),





                                      ],
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                    ),
                                  ),


                                ],
                              ),
                            );

                          },
                        );
                      },
                    ),
                  );

                },
              ),
            ),
            Text('Assigned: ${getFieldValue('assigned')}'),

            Text('Category: ${getFieldValue('category')}'),
            Text('Choose: ${getFieldValue('choose')}'),
            Text('COD: ${getFieldValue('cod')}'),
            Text('Created At: ${getFieldValue('created_at')}'),
            Text('DateTime: ${getFieldValue('dateTime')}'),
            Text('Description: ${getFieldValue('description')}'),
            Text('From Address: ${getFieldValue('fromaddress')}'),
            Text('From Latitude: ${getFieldValue('fromlatitude')}'),
            Text('From Longitude: ${getFieldValue('fromlongitude')}'),
            ElevatedButton(
              onPressed: () {
                double? fromLatitude = getFieldDoubleValue('fromlatitude');
                double? fromLongitude = getFieldDoubleValue('fromlongitude');
                if (fromLatitude != null && fromLongitude != null) {
                  _openGoogleMaps(fromLatitude, fromLongitude);
                }
              },
              child: Text('Navigate to From Location'),
            ),
            Text('ID: ${getFieldValue('id')}'),
            Text('Negotiable: ${getFieldValue('negotiable')}'),
            Text('Payment: ${getFieldValue('payment')}'),
            Text('Payment ID: ${getFieldValue('paymentID')}'),
            Text('Picked: ${getFieldValue('picked')}'),
            Text('Priority: ${getFieldValue('priority')}'),
            Text('Profession: ${getFieldValue('prof')}'),
            Text('Reached: ${getFieldValue('reached')}'),
            Text('Review Done: ${getFieldValue('reviewdone')}'),
            Text('Status: ${getFieldValue('status')}'),
            Text('Tip: ${getFieldValue('tip')}'),
            Text('To Address: ${getFieldValue('toaddress')}'),
            Text('To Latitude: ${getFieldValue('tolatitude')}'),
            Text('To Longitude: ${getFieldValue('tolongitude')}'),
            ElevatedButton(
              onPressed: () {
                double? toLatitude = getFieldDoubleValue('tolatitude');
                double? toLongitude = getFieldDoubleValue('tolongitude');
                if (toLatitude != null && toLongitude != null) {
                  _openGoogleMaps(toLatitude, toLongitude);
                }
              },
              child: Text('Navigate to To Location'),
            ),
            Text('Work By: ${getFieldValue('workBy')}'),
            Container(
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('users').doc(getFieldValue('workBy')).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {


                    return Container(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    );
                  } else if (userSnapshot.hasError) {


                    return Text('Error: ${userSnapshot.error}');
                  } else if (!userSnapshot.hasData || !userSnapshot.data!.exists) {


                    return Text('User not found');
                  }


                  // Access user data and display details
                  Map<String, dynamic> userData = userSnapshot.data!.data()!;
                  String userName = userData['name'] ?? '';
                  String mobile = userData['mobile'] ?? "";



                  // Display worker information
                  return Container(
                    height: 150,
                    width: screenWidth,

                    margin: EdgeInsets.only(top: 12, bottom: 10, right: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(30.0),
                      color: Colors.transparent,

                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(left: 12,right: 10,top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                child: Column(
                                  children: [
                                    Container(
                                      child: Text(
                                        userData['name'],
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: screenWidth*0.05,
                                          overflow: TextOverflow.ellipsis, // or TextOverflow.ellipsis, etc.
                                        ),
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        userData['email'],
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: screenWidth*0.039,
                                          overflow: TextOverflow.ellipsis, // or TextOverflow.ellipsis, etc.
                                        ),
                                      ),
                                    ),
                                    Container(
                                      child: Text(
                                        userData['mobile'],
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: screenWidth*0.05,
                                          overflow: TextOverflow.ellipsis, // or TextOverflow.ellipsis, etc.
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            print("usernumber from direction screen");
                                            print(userData['mobile']);
                                            FlutterPhoneDirectCaller.callNumber(userData['mobile']);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.pink),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.call,
                                            color: Colors.pink,
                                          ),
                                          label: Text(
                                            'Call',
                                            style: TextStyle(
                                              color: Colors.pink,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 20,),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            launchWhatsApp(phone: "+91"+userData['mobile'], message: 'From Perpenny');

                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Colors.green),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                          ),
                                          icon: Container(
                                            width: 24.0,
                                            height: 24.0,
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                image: AssetImage('assets/social.png'),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          label: Text(
                                            'Whatsapp',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      ],
                                    )



                                  ],
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                ),
                              ),

                            ],
                          ),
                        ),


                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Enter your note...',
              ),
            ),

            // Button to post the note
            ElevatedButton(
              onPressed: () {
                String note = noteController.text.trim();
                if (note.isNotEmpty) {
                  _addNote(note);
                  noteController.clear();
                }
              },
              child: Text('Post Note'),
            ),

            SizedBox(height: 10),
            Container(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('work')
                    .doc(work.id)
                    .collection('notes')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var works = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: works.length,
                    itemBuilder: (context, index) {
                      var work = works[index];
                      return ListTile(
                        title: Text(work['note'] ?? 'No Name'),


                      );
                    },
                  );
                },
              ),
            ),
            Text('Worker Amount: ${getFieldValue('workeramount')}'),
            OutlinedButton.icon(
              onPressed: () {
                _deleteWork(context,getFieldValue('workBy').toString());
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.pink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              icon: Icon(
                Icons.delete,
                color: Colors.pink,
              ),
              label: Text(
                'Cancel Work',
                style: TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  PaymentScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.pink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              icon: Icon(
                Icons.money,
                color: Colors.pink,
              ),
              label: Text(
                'Request Payment',
                style: TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )

          ],
        ),
      ),
    );
  }
}
