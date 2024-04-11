import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fraction/fraction.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeDetailsPage extends StatefulWidget {
  final DocumentSnapshot recipeSnapshot;

  const RecipeDetailsPage({Key? key, required this.recipeSnapshot})
      : super(key: key);

  @override
  _RecipeDetailsPageState createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late VideoWidget _videoWidget;
  late UploaderDetailsWidget _UploaderDetailsWidget;
  late TabViewWidget _tabViewWidget;
  late TextEditingController _commentController;

  int _servings = 0;
  String _userEmail = '';
  bool _isLiked = false;
  bool _isSaved = false;
  Map<int, bool> _isChecked = {};

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _videoWidget = VideoWidget(recipeSnapshot: widget.recipeSnapshot);
    _UploaderDetailsWidget =
        UploaderDetailsWidget(recipeSnapshot: widget.recipeSnapshot);
    _getUserEmail(); 
    _loadLikeStatus();
    _loadSaveStatus();
  _servings = widget.recipeSnapshot['serving'] ?? 1; 
    _loadCheckboxStates(); 
  }

  void _getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email') ?? ''; // Fetch user's email
    });
  }

  void _loadLikeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLiked = prefs.getBool(widget.recipeSnapshot.id) ?? false;
    setState(() {
      _isLiked = isLiked;
    });
  }

  void _loadSaveStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isSaved = prefs.getBool(widget.recipeSnapshot.id) ?? false;
    setState(() {
      _isSaved = isSaved;
    });
  }

  void _toggleSaveStatus() async {
    setState(() {
      _isSaved = !_isSaved;
    });

   
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(widget.recipeSnapshot.id, _isSaved);

    String userId = _userEmail;

    if (_isSaved) {
      // Add the recipe ID to the user's saved recipes collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savedRecipes')
          .doc(widget.recipeSnapshot.id)
          .set({
        'recipeId': widget.recipeSnapshot.id,
      });
    } else {
      // Remove the recipe ID from the user's saved recipes collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savedRecipes')
          .doc(widget.recipeSnapshot.id)
          .delete();
    }
  }
void toggleCheckbox(int index) {
  setState(() {
    _isChecked[index] = !(_isChecked[index] ?? false);
  });
  _saveCheckboxStates();
}

void _saveCheckboxStates() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('checkboxStates', jsonEncode(_isChecked));
}
void _loadCheckboxStates() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? checkboxStatesJson = prefs.getString('checkboxStates');
  if (checkboxStatesJson != null && checkboxStatesJson.isNotEmpty) {
    Map<String, dynamic> decodedMap = jsonDecode(checkboxStatesJson);
    setState(() {
      _isChecked = decodedMap.map((key, value) => MapEntry(int.parse(key), value));
    });
  }
}
  @override
  Widget build(BuildContext context) {
    _tabViewWidget = TabViewWidget(
      recipeSnapshot: widget.recipeSnapshot,
      servings: _servings,
      currentPageIndex: _currentPageIndex,
      updateServings: _updateServings,
      updateCurrentPageIndex: _updateCurrentPageIndex,
       isChecked: _isChecked,
    toggleCheckbox: toggleCheckbox
     
    );

    return Scaffold(
      backgroundColor: Color(0xFFD1E7D2),
      appBar: AppBar(
          backgroundColor: Color(0xFFD1E7D2),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          //title: Text('Recipe Details'),
      ),
      body: ListView(
        
        children: [
           
          _videoWidget,
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                
                Expanded(
                  child: Text(
                    widget.recipeSnapshot['title'], // Display recipe title here
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLiked ? Icon(Icons.thumb_up) : Icon(Icons.thumb_up_alt_outlined),
                  onPressed: () async {
                    setState(() {
                      _isLiked = !_isLiked;
                    });

                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.setBool(widget.recipeSnapshot.id, _isLiked);

                    DocumentReference recipeRef = FirebaseFirestore.instance
                        .collection('recipe')
                        .doc(widget.recipeSnapshot.id);

                    if (_isLiked) {
                      await recipeRef.update({'likes': FieldValue.increment(1)});
                    } else {
                      await recipeRef.update({'likes': FieldValue.increment(-1)});
                    }
                  },
                ),
                IconButton(
                    icon: _isSaved ? Icon(Icons.bookmark) : Icon(Icons.bookmark_border),
                    onPressed: _toggleSaveStatus,
                 ),
              ],
            ),
          ),
          _UploaderDetailsWidget,
          _tabViewWidget,
        ],
      ),
    );
  }

  void _updateServings(int newServings) {
    setState(() {
      _servings = newServings;
    });
  }

  int _currentPageIndex = 0;
  void _updateCurrentPageIndex(int newIndex) {
    setState(() {
      _currentPageIndex = newIndex;
    });
  }
}

class VideoWidget extends StatefulWidget {
  final DocumentSnapshot recipeSnapshot;

  const VideoWidget({Key? key, required this.recipeSnapshot}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isVideoLoading = true;
  


  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

 @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  void _initializeVideo() async {
    try {
      String videoUrl = await getVideoUrl(widget.recipeSnapshot['video']);
      // ignore: deprecated_member_use
      _videoPlayerController = VideoPlayerController.network(videoUrl);
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        allowFullScreen: true, 
        aspectRatio: 4 / 3,
        useRootNavigator: true,
        
      );
      _videoPlayerController.addListener(() {
        if (_videoPlayerController.value.hasError) {
          print(
              "Video player error: ${_videoPlayerController.value.errorDescription}");
        }
      });

      setState(() {
        _isVideoLoading = false;
      });
    } catch (e) {
      print('error initializing video:$e');
    }
  }

  Future<String> getVideoUrl(String videoName) async {
    final ref = FirebaseStorage.instance.ref().child(videoName);
    final url = await ref.getDownloadURL();
    return url;
  }
 @override
  Widget build(BuildContext context) {
    return _isVideoLoading
        ? AspectRatio(
            aspectRatio: 4 / 3, // Set a default aspect ratio while loading
            child: Center(child: CircularProgressIndicator()),
          )
        : AspectRatio(
            aspectRatio: _chewieController.aspectRatio ?? 16 / 9,
            child: Chewie(
              controller: _chewieController,
            ),
          );
  }
}


class UploaderDetailsWidget extends StatelessWidget {
  final DocumentSnapshot recipeSnapshot;

  const UploaderDetailsWidget({Key? key, required this.recipeSnapshot})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(recipeSnapshot['userid'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFD1E7D2)),
            strokeWidth: 2.0,
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Text('User not found');
        }

        var userData = snapshot.data!;
        String username = userData['name'] ?? 'Unknown User';
        String profilePicture = userData['profilepic'] ?? '';

        return Row(
          children: [
            FutureBuilder(
              future: FirebaseStorageService.getImageUrl(profilePicture),
              builder: (context, urlSnapshot) {
                if (urlSnapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD1E7D2)),
                    strokeWidth: 2.0,
                  );
                } else if (urlSnapshot.hasError) {
                  return Text('Error: ${urlSnapshot.error}');
                } else {
                  var url = urlSnapshot.data as String;
                  return CircleAvatar(
                    backgroundImage: NetworkImage(url),
                  );
                }
              },
            ),
            SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: 250), // Adjust the max width as needed
                child: ListTile(
                  title: Text(
                    username,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.share),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TabViewWidget extends StatelessWidget {
  final DocumentSnapshot recipeSnapshot;
  final int servings;
  final int currentPageIndex;
  final Function(int) updateServings;
  final Function(int) updateCurrentPageIndex;
  final TextEditingController _commentController = TextEditingController();
   final Map<int, bool> isChecked; // Receive _isChecked map from parent
  final Function(int) toggleCheckbox; //

  TabViewWidget({
    Key? key,
    required this.recipeSnapshot,
    required this.servings,
    required this.currentPageIndex,
    required this.updateServings,
    required this.updateCurrentPageIndex,
      required this.isChecked,
    required this.toggleCheckbox, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Ingredients'),
              Tab(text: 'Start Cook'),
              Tab(text: 'Comments'),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _buildIngredientsTab(),
                _buildStartCookTab(),
                _buildCommentsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildIngredientsTab() {
  final recipeSnapshot = this.recipeSnapshot;
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('recipe')
                .doc(recipeSnapshot.id)
                .collection('ingredients')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No ingredients found');
              }

              List<QueryDocumentSnapshot> ingredients = snapshot.data!.docs;
              int totalIngredients = ingredients.length;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingredients- $totalIngredients',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity for $servings Serving',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: () {
                              if (servings > 1) {
                                updateServings(servings - 1);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              updateServings(servings + 1);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: ingredients.length,
                    itemBuilder: (context, index) {
                      String name = ingredients[index].id;
                      String quantity = ingredients[index]['quantity'];
                      String unit = _getUnit(ingredients[index]);                      
                      String adjustedQuantity = _calculateAdjustedQuantity(quantity, servings);
                      return ListTile(
                        title: Text('$name : $adjustedQuantity $unit  '),
                        trailing: Checkbox(
                          value: isChecked[index] ?? false,
                          onChanged: (value) {
                            toggleCheckbox(index);
                            if (value == true) {
                              // Add ingredient to selectedIngredients in Firestore
                              _addIngredientToSelectedIngredients(name);
                            } else {
                              // Remove ingredient from selectedIngredients in Firestore
                              _removeIngredientFromSelectedIngredients(name);
                            }
                          },
                          activeColor: Colors.transparent,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
String _calculateAdjustedQuantity(String originalQuantity, int servings) {
   
   Fraction originalFraction = _parseQuantity(originalQuantity);

   MixedFraction adjustedFraction = (originalFraction * Fraction(servings, 1)).toMixedFraction();
  if (adjustedFraction.numerator == 0 || adjustedFraction.denominator == 1 ) {
       
        return adjustedFraction.toFraction().toString();
    } else {
       
        return adjustedFraction.toString();
   }
}


Fraction _parseQuantity(String quantity) {
  try {
    // Check if the quantity contains a space, indicating a mixed fraction
    if (quantity.contains(' ')) {
      // Split the mixed fraction into whole number, numerator, and denominator
      List<String> parts = quantity.split(' ');
      int wholeNumber = int.parse(parts[0]);
      String fraction = parts[1];

      // Split the fraction into numerator and denominator
      List<String> fractionParts = fraction.split('/');
      int numerator = int.parse(fractionParts[0]);
      int denominator = int.parse(fractionParts[1]);

      // Calculate the equivalent improper fraction
      int improperNumerator = wholeNumber * denominator + numerator;

      // Create and return the mixed fraction
      return Fraction(improperNumerator, denominator);
    }

    // Check if the quantity contains a slash, indicating a fraction
    else if (quantity.contains('/')) {
      // Split the fraction into numerator and denominator
      List<String> parts = quantity.split('/');
      int numerator = int.parse(parts[0]);
      int denominator = int.parse(parts[1]);

      // Create and return the fraction
      return Fraction(numerator, denominator);
    }

    // If the quantity is a whole number, parse it as an integer
    else {
      return Fraction.fromString(quantity);
    }
  } catch (e) {
    print('Error parsing quantity: $e');
    // Return a default fraction if an error occurs during parsing
    return Fraction(0, 1);
  }
}



String _getUnit(QueryDocumentSnapshot ingredient) {
  final data = ingredient.data() as Map<String, dynamic>?; 
  return data != null && data.containsKey('unit') ? data['unit'] as String : '';
}
void _addIngredientToSelectedIngredients(String ingredientName) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('email');
  if (userId != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'selectedIngredients': FieldValue.arrayUnion([ingredientName])
    });
  }
}


void _removeIngredientFromSelectedIngredients(String ingredientName) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('email');
  if (userId != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'selectedIngredients': FieldValue.arrayRemove([ingredientName])
    });
  }
}



Widget _buildStartCookTab() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('recipe')
        .doc(recipeSnapshot.id)
        .collection('steps')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFD1E7D2)),
          strokeWidth: 2.0,
        );
      }
      if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      }
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Text('No steps found');
      }

      List<QueryDocumentSnapshot> steps = snapshot.data!.docs;
      if (currentPageIndex >= steps.length) {
        updateCurrentPageIndex(steps.length - 1);
      }

      String currentStep =
          steps.isNotEmpty ? steps[currentPageIndex]['description'] : '';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Step ${currentPageIndex + 1}:',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.0),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    if (currentPageIndex > 0) {
                      updateCurrentPageIndex(currentPageIndex - 1);
                    }
                  },
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFD1E7D2)),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      currentStep,
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios),
                  onPressed: () {
                    if (currentPageIndex < steps.length - 1) {
                      updateCurrentPageIndex(currentPageIndex + 1);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20.0),
          ],
        ),
      );
    },
  );
}



  Widget _buildCommentsTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('recipe')
                .doc(recipeSnapshot.id)
                .collection('comments')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(const Color(0xFFD1E7D2)),
                  strokeWidth: 2.0,
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No comments yet'));
              }

              List<QueryDocumentSnapshot> comments = snapshot.data!.docs;
              return ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  var comment = comments[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(comment['userid'])
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFD1E7D2)),
                          strokeWidth: 2.0,
                        );
                      }
                      if (userSnapshot.hasError) {
                        return Text('Error: ${userSnapshot.error}');
                      }
                      if (!userSnapshot.hasData || userSnapshot.data == null) {
                        return SizedBox(); // Placeholder for loading state
                      }

                      var userData = userSnapshot.data!;
                      String username = userData['name'] ?? 'Unknown User';
                      String profilePicture = userData['profilepic'] ?? '';

                      
                      return ListTile(
                        leading: FutureBuilder(
                          future: FirebaseStorageService.getImageUrl(
                              profilePicture), // Use the FirebaseStorageService to get the image URL
                          builder: (context, urlSnapshot) {
                            if (urlSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFFD1E7D2)),
                                strokeWidth: 2.0,
                              );
                            } else if (urlSnapshot.hasError) {
                              return Text('Error: ${urlSnapshot.error}');
                            } else {
                              var url = urlSnapshot.data as String;
                              return CircleAvatar(
                                backgroundImage: NetworkImage(url),
                              );
                            }
                          },
                        ),
                        title: Text(comment['comment']),
                        subtitle: Text(username),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              FutureBuilder(
                future: SharedPreferences.getInstance(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFFD1E7D2),
                      ),
                      strokeWidth: 2.0,
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    SharedPreferences prefs = snapshot.data as SharedPreferences;
                    String currentUserEmail = prefs.getString('email') ?? '';

                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserEmail) // Fetch user document by document ID (which is the email)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFD1E7D2),
                            ),
                            strokeWidth: 2.0,
                          );
                        } else if (userSnapshot.hasError) {
                          return Text('Error: ${userSnapshot.error}');
                        } else if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          // Handle case where user document is not found
                          return Text('User not found');
                        } else {
                          var userData = userSnapshot.data!.data();
                          String currentUserProfilePic =
                              userData?['profilepic'] ?? ''; // Assuming 'profilepic' field exists in your user document

                          return FutureBuilder(
                            future: FirebaseStorageService.getImageUrl(
                                currentUserProfilePic),
                            builder: (context, urlSnapshot) {
                              if (urlSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFFD1E7D2),
                                  ),
                                  strokeWidth: 2.0,
                                );
                              } else if (urlSnapshot.hasError) {
                                return Text('Error: ${urlSnapshot.error}');
                              } else {
                                var url = urlSnapshot.data as String;
                                return CircleAvatar(
                                  backgroundImage: NetworkImage(url),
                                );
                              }
                            },
                          );
                        }
                      },
                    );
                  }
                },
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: Colors.grey,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: 'Write your comment...',
                              border: InputBorder.none,
                            ),
                            // You can use a TextEditingController to get the comment text
                            controller: _commentController,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () async {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          String? userId = prefs.getString('email'); 

                          if (userId != null) {
                            // Check if the comment field is not empty
                            if (_commentController.text.isNotEmpty) {
                              try {
                                // Post comment to Firestore
                                await FirebaseFirestore.instance
                                    .collection('recipe')
                                    .doc(recipeSnapshot.id)
                                    .collection('comments')
                                    .add({
                                  'comment': _commentController.text,
                                  'userid': userId,
                                });

                                // Optionally, you can clear the comment input field after submission
                                _commentController.clear();
                              } catch (e) {
                                print('Error posting comment: $e');
                                // Handle error here
                              }
                            } else {
                              // Optionally, you can inform the user that the comment field is empty
                              print('Please enter a comment.');
                            }
                          } else {
                            // If user ID is not found in SharedPreferences, handle the situation accordingly
                            print('User ID not found. Unable to submit comment.');
                          }
                        },
                      ),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FirebaseStorageService {
  static Future<String> getImageUrl(String? imageName) async {
    if (imageName == null || imageName.isEmpty) {
      // Return a placeholder image URL or handle the case as needed
      return ''; // For example, return a default placeholder image URL
    }
    final ref = FirebaseStorage.instance.ref().child(imageName);
    try {
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      // Handle errors, such as image not found
      print('Error fetching image URL: $e');
      return ''; // Return a default placeholder image URL or handle the error case as needed
    }
  }
}