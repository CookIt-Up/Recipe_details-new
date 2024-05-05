import 'package:cookitup/uploader_profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FollowersListPage extends StatelessWidget {
  final String email;

  const FollowersListPage({Key? key, required this.email}) : super(key: key);

  Future<String> getImageUrl(String imageName) async {
    final ref = FirebaseStorage.instance.ref().child(imageName);
    final url = await ref.getDownloadURL();
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('followers')
            .snapshots(),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            var followers = snapshot.data.docs;
            return ListView.builder(
              itemCount: followers.length,
              itemBuilder: (context, index) {
                var followerEmail = followers[index].id;
                return FutureBuilder(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: followerEmail)
                      .get(),
                  builder: (context, AsyncSnapshot userSnapshot) {
                    if (userSnapshot.hasData) {
                      var userData = userSnapshot.data.docs.first.data();
                      var name = userData['name'] ?? 'No Name';
                      var profilePic = userData['profilepic'] ?? 'default_profile_pic_url'; // Use a default profile pic URL if profile pic is null
                      return GestureDetector(
                        onTap: () {
                          // Navigate to follower's profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UploaderProfilePage(email: followerEmail),
                            ),
                          );
                        },
                        child: FutureBuilder<String>(
                          future: getImageUrl(profilePic),
                          builder: (context, urlSnapshot) {
                            if (urlSnapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator(color: Colors.white,);
                            } else if (urlSnapshot.hasError) {
                              return Text('Error: ${urlSnapshot.error}');
                            } else {
                              String imageUrl = urlSnapshot.data!;
                              return ListTile(
                                title: Text(name),
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(imageUrl),
                                ),
                                // You can add more details if needed
                              );
                            }
                          },
                        ),
                      );
                    } else {
                      return Container(); // Placeholder widget while loading
                    }
                  },
                );
              },
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white,),
            );
          }
        },
      ),
    );
  }
}

class FollowingListPage extends StatelessWidget {
  final String email;

  const FollowingListPage({Key? key, required this.email}) : super(key: key);

  Future<String> getImageUrl(String imageName) async {
    final ref = FirebaseStorage.instance.ref().child(imageName);
    final url = await ref.getDownloadURL();
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('following')
            .snapshots(),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            var following = snapshot.data.docs;
            return ListView.builder(
              itemCount: following.length,
              itemBuilder: (context, index) {
                var followedEmail = following[index].id;
                return FutureBuilder(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: followedEmail)
                      .get(),
                  builder: (context, AsyncSnapshot userSnapshot) {
                    if (userSnapshot.hasData) {
                      var userData = userSnapshot.data.docs.first.data();
                      var name = userData['name'] ?? 'No Name';
                      var profilePic = userData['profilepic'] ?? 'default_profile_pic_url'; // Use a default profile pic URL if profile pic is null
                      return GestureDetector(
                        onTap: () {
                          // Navigate to followed user's profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UploaderProfilePage(email: followedEmail),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(profilePic),
                          ),
                          title: Text(name),
                          // You can add more details if needed
                        ),
                      );
                    } else {
                      return const ListTile(
                        title: Text('Loading...'),
                      );
                    }
                  },
                );
              },
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white,),
            );
          }
        },
      ),
    );
  }
}
