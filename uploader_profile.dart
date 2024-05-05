import 'package:cookitup/recipe_details.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookitup/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookitup/connections.dart';

class UploaderProfilePage extends StatefulWidget {
  final String email;

  const UploaderProfilePage({Key? key, required this.email}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UploaderProfilePage> {
  String _userName = '';
  int _followers = 0;
  int _following = 0;
  int _video = 0;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _initFollowingStatus();
  }

Future<void> _fetchUserProfile() async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.email)
        .get();

    if (this.mounted && userDoc.docs.isNotEmpty) {
      final userData = userDoc.docs.first.data() as Map<String, dynamic>?;
      print('User Data: $userData'); // Print user data for debugging
      if (userData != null) {
        setState(() {
          _userName = userData['name'] ?? ''; // Ensure a default value if null
          _followers = userData['followers'] ?? 0; // Ensure a default value if null
          _following = userData['following'] ?? 0; // Ensure a default value if null
          _video = userData['videos'] ?? 0; // Ensure a default value if null
        });
      } else {
        print('User data is null');
      }
    } else {
      print('No user document found for email: ${widget.email}');
    }
  } catch (error) {
    print('Error fetching user profile: $error');
  }
}

final CollectionReference recipe =
      FirebaseFirestore.instance.collection('recipe');

Future<void> _initFollowingStatus() async {
    String? currentUserEmail = await _getCurrentUserEmail();
    if (currentUserEmail != null) {
      final followingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .collection('following')
          .doc(widget.email)
          .get();

      setState(() {
        _isFollowing = followingDoc.exists;
      });
    }
  }
@override
Widget build(BuildContext context) {
  return FutureBuilder<String?>(
    future:_getCurrentUserEmail(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator(color: Colors.green[100]);
      } else if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      } else {
        String? currentUserEmail = snapshot.data;
        if (widget.email == currentUserEmail) {
          return UserProfileScreen(); // Navigate to ProfilePage if the email matches
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              
            ],
          ),
          body: Container(
            padding: EdgeInsets.all(20),
            color: Colors.green[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FutureBuilder<String>(
                  future: _fetchProfilePictureUrl(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator(color: Colors.green[100]);
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      String avatarUrl = snapshot.data!;
                      // Use the avatarUrl to fetch the image from Firebase Storage
                      return FutureBuilder<String>(
                        future: getImageUrl(avatarUrl),
                        builder: (context, UrlSnapshot) {
                          if (UrlSnapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color.fromARGB(255, 255, 255, 255),
                              ),
                              strokeWidth: 5.0,
                            );
                          } else if (UrlSnapshot.hasError) {
                            return Text('Error: ${UrlSnapshot.error}');
                          } else {
                            String imageUrl = UrlSnapshot.data!;
                            // Use the imageUrl to display the image
                            return CircleAvatar(
                              backgroundImage: NetworkImage(imageUrl),
                              radius: 50,
                            );
                          }
                        },
                      );
                    }
                  },
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    
                  ],
                ),
                SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$_followers Followers.  ',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FollowersListPage(email: widget.email),
                              ),
                            );
                          },
                      ),
                      
                      TextSpan(
                        text: '$_following Following.  ',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FollowingListPage(email: widget.email),
                              ),
                            );
                          },
                      ),
                    
                      TextSpan(text: '$_video Videos'),
                    ],
                  ),
                ),

                SizedBox(height: 20),
    
                Container(
                  margin: EdgeInsets.symmetric(vertical: 20),
                  child: ElevatedButton(
                    onPressed: () async {
  try {
    String? currentUserEmail = await _getCurrentUserEmail();
    if (currentUserEmail != null) {
      final userRef = FirebaseFirestore.instance.collection('users');

      if (_isFollowing) {
        // Unfollow logic
        await userRef
            .doc(currentUserEmail)
            .collection('following')
            .doc(widget.email)
            .delete();

        await userRef.doc(widget.email).update({'followers': FieldValue.increment(-1)});
        await userRef.doc(currentUserEmail).update({'following': FieldValue.increment(-1)});
        // Remove current user from profile user's followers
        await userRef
            .doc(widget.email)
            .collection('followers')
            .doc(currentUserEmail)
            .delete();

        setState(() {
          _isFollowing = false;
          _followers--;
          
        });
      } else {
        // Follow logic
        await userRef
            .doc(currentUserEmail)
            .collection('following')
            .doc(widget.email)
            .set({});

        await userRef.doc(widget.email).update({'followers': FieldValue.increment(1)});
        await userRef.doc(currentUserEmail).update({'following': FieldValue.increment(1)});

        // Add current user to profile user's followers
        await userRef
            .doc(widget.email)
            .collection('followers')
            .doc(currentUserEmail)
            .set({});

        setState(() {
          _isFollowing = true;
         
          _following++;
        });
      }
    } else {
      print('Current user email is null');
    }
  } catch (error) {
    print('Error toggling following status: $error');
  }
},

                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return const Color.fromARGB(255, 27, 111, 29); // Green when pressed
                        }
                        return _isFollowing ? Colors.grey : Color.fromARGB(255, 29, 92, 32); // Green if not followed
                      }),
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Expanded(
  child: StreamBuilder(
    stream: recipe.orderBy('likes', descending: true).snapshots(),
    builder: (context, AsyncSnapshot snapshot) {
      if (snapshot.hasData) {
        var filteredDocs = snapshot.data.docs.where((doc) {
          var userId = doc['userid'];
          return userId == widget.email; // Use widget.email for uploader's email
        }).toList();

        return GridView.builder(
          itemCount: filteredDocs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemBuilder: (context, index) {
            var document = filteredDocs[index];
            var thumbnailPath = document['thumbnail'];

            return FutureBuilder(
              future: getImageUrl(thumbnailPath),
              builder: (context, urlSnapshot) {
                if (urlSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(color: Color.fromRGBO(200, 230, 201, 1));
                } else if (urlSnapshot.hasError) {
                  return Text('Error: ${urlSnapshot.error}');
                } else {
                  var url = urlSnapshot.data as String;

                  return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeDetailsPage(recipeSnapshot: document),
                      ),
                    );
                  },
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      } else {
        return Container();
      }
    },
  ),
),


              ],
            ),
          ),
        );
      }
    },
  );
}


Future<String> _fetchProfilePictureUrl() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: widget.email)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data() as Map<String, dynamic>;
        return userData['profilepic'] ?? '';
      }

      return ''; // Return empty string if no profile picture found
    } catch (error) {
      print('Error fetching profile picture URL: $error');
      return ''; // Return empty string in case of error
    }
  }
}
Future<String> getImageUrl(String imageName) async {
    final ref = FirebaseStorage.instance.ref().child(imageName);
    final url = await ref.getDownloadURL();
    return url;
  }
Future<String?>? _getCurrentUserEmail() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('email');
}
