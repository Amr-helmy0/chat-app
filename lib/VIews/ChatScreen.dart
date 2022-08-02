import 'dart:io';
import 'package:chatnewss/Services/database.dart';
import 'package:chatnewss/VIews/Home.dart';
import 'package:chatnewss/allConstants/size_constants.dart';
import 'package:chatnewss/helperfunctions/shardpref_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String chatWithUsername, name ,profileUrl ;

  ChatScreen(this.chatWithUsername, this.name,  this.profileUrl  );
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String message="";
  String chatRoomId, messageId = "";
  String profilePicUrl = "", name = "", username = "";
  Stream messageStream,pickStream;
  String myName, myProfilePic, myUserName, myEmail;
  TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  PlatformFile pickedFile;
  UploadTask uploadTask;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  File imageFile;


  Future getImage() async {
    ImagePicker _picker = ImagePicker();
    await _picker.pickImage(source: ImageSource.gallery).then((xFile) {
      if (xFile != null) {
        imageFile = File(xFile.path);
        uploadImage();
      }
    });
  }

  Future uploadImage() async {
    String fileName = Uuid().v1();
    int status = 1;

    await _firestore
        .collection('chatrooms')
        .doc(chatRoomId)
        .collection('chats')
        .doc(fileName)
        .set({
      "sendby": _auth.currentUser.displayName,
      "message": "",
      "type": "img",
      "ts": FieldValue.serverTimestamp(),
    });

    var ref =
    FirebaseStorage.instance.ref().child('images').child("$fileName.jpg");

    var uploadTask = await ref.putFile(imageFile).catchError((error) async {
      await _firestore
          .collection('chatrooms')
          .doc(chatRoomId)
          .collection('chats')
          .doc(fileName)
          .delete();

      status = 0;
    });

    if (status == 1) {
      String imageUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('chatrooms')
          .doc(chatRoomId)
          .collection('chats')
          .doc(fileName)
          .update({"message": imageUrl});
      print(imageUrl);
    }
  }






  getMyInfoFromSharedPreference() async {
    myName = await SharedPreferenceHelper().getDisplayName();
    myProfilePic = await SharedPreferenceHelper().getUserProfileUrl();
    myUserName = await SharedPreferenceHelper().getUserName();
    myEmail = await SharedPreferenceHelper().getUserEmail();

    chatRoomId = getChatRoomIdByUsernames(widget.chatWithUsername, myUserName,);
  }

  getChatRoomIdByUsernames(String a, String b) {
    if (a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)) {
      return "$b\_$a";
    } else {
      return "$a\_$b";
    }
  }

  SendMessage(bool sendClicked) {
    if (message != "") {

      var lastMessageTs = DateTime.now();

      Map<String, dynamic> messageInfoMap = {
        "message": message,
        "sendBy": myUserName,
        "ts": lastMessageTs,
        "imgUrl": myProfilePic

      };

      //messageId
      if (messageId == "") {
        messageId = randomAlphaNumeric(12);
      }

      DatabaseMethods()
          .addMessage(chatRoomId, messageId, messageInfoMap)
          .then((value) {
        Map<String, dynamic> lastMessageInfoMap = {
          "lastMessage": message,
          "lastMessageSendTs": lastMessageTs,
          "lastMessageSendBy": myUserName
        };

        DatabaseMethods().updateLastMessageSend(chatRoomId, lastMessageInfoMap);

        if (sendClicked) {
          // remove the text in the message input field
          message = "";
          // make message id blank to get regenerated on next message send
          messageId = "";
        }
      });
    }
  }


  Widget chatMessageBody(String message, bool sendByMe ) {
    return Row(
      mainAxisAlignment:
      sendByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            children: [
              Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomRight:
                      sendByMe ? Radius.circular(0) : Radius.circular(24),
                      topRight: Radius.circular(24),
                      bottomLeft:
                      sendByMe ? Radius.circular(24) : Radius.circular(0),
                    ),
                    color: sendByMe ? HexColor("#80B1FE") : HexColor("#F1F4F7"),
                  ),
                  padding: EdgeInsets.all(16),
                  child:  Text(
                    message,
                    style:sendByMe ?
                    TextStyle(color: Colors.white,fontSize: 15,fontWeight: FontWeight.bold):
                    TextStyle(color: Colors.black,fontSize: 15,fontWeight: FontWeight.bold),
                  )
              ),
              Container(
                child: Text(
                  DateFormat('hh:mm a').format(DateTime.now()),
                  style: TextStyle(color: HexColor("#3D455A"),fontSize: 8),
                ),),
            ],
          ),
        ),
      ],
    );
  }

  Widget chatMessages() {
    return StreamBuilder(
      stream: messageStream ,
      builder: (context, snapshot) {
        return snapshot.hasData
            ? ListView.builder(
            padding: EdgeInsets.only(bottom: 70, top: 16),
            itemCount: snapshot.data.docs.length,
            reverse: true,
            itemBuilder: (context, index) {
              DocumentSnapshot ds = snapshot.data.docs[index];
              return chatMessageBody(

                  ds["message"], myUserName == ds["sendBy"]);
            }):Center(child: CircularProgressIndicator(),);
      },
    );
  }


  getAndSetMessages() async {
    messageStream = await DatabaseMethods().getChatRoomMessages(chatRoomId);
    setState(() {});
  }

  doThisOnLaunch() async {
    await getMyInfoFromSharedPreference();
    getAndSetMessages();
  }

  @override
  void initState() {
    controller.text ="";
    doThisOnLaunch();
    super.initState();
  }





  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        brightness: Brightness.dark,
        //remove bcakgroundcolor from appbar
        backgroundColor: Colors.transparent,
        //remove shadwo frome app bar
        elevation:0,
        flexibleSpace:Container(
          margin: EdgeInsets.only(top: 30),
          child: Row(
            children: [
              IconButton(
                icon:  Icon(Icons.arrow_back_ios, color: Colors.black,),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder:(context)=>Home(),
                ),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: NetworkImage(widget.profileUrl,),
              ),
              SizedBox(width: 10,),
              Text(
                widget.name,
                style: TextStyle(color: HexColor("#222B45")
                ),
              ),
            ],
          ),
        ),


      ),
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage("assets/lottie/back.jpg"),
              fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            chatMessages(),
            Container(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(right: Sizes.dimen_4),
                decoration: BoxDecoration(
                  color:HexColor("#F1F4F7"),
                  borderRadius: BorderRadius.circular(Sizes.dimen_30),
                ),
                padding: EdgeInsets.symmetric(horizontal:15, vertical: 1),
                child: Row(
                  children: [
                    Container(
                      //add message
                      child: Flexible(
                        child: TextField(
                          focusNode: focusNode,
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          controller: controller,
                          onChanged: (value) {
                            message =value;
                            //addMessage(false);
                          },
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(onPressed: getImage  ,
                                icon: Icon(Icons.image)
                            ),
                            hintText: "Write a message…",
                            border: InputBorder.none,
                            hintStyle:
                            TextStyle(color: Colors.black.withOpacity(0.6)
                            ),
                            focusedBorder:OutlineInputBorder(
                              borderSide:  BorderSide(color: Colors.transparent, width: 0.0),
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),

                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: Sizes.dimen_2),
                      decoration: BoxDecoration(
                        color:  HexColor("#80B1FE"),
                        borderRadius: BorderRadius.circular(Sizes.dimen_36),
                      ),
                      //send message
                      child: IconButton(
                        onPressed: () {
                          controller.text="";
                          SendMessage(true);
                        },
                        icon: const Icon(Icons.send_rounded),
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ShowImage extends StatelessWidget {
  final String imageUrl;

  const ShowImage({ this.imageUrl, Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        color: Colors.black,
        child: Image.network(imageUrl),
      ),
    );
  }
}
