import 'package:chatnewss/Services/auth.dart';
import 'package:chatnewss/VIews/Home.dart';
import 'package:chatnewss/VIews/Signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
       home: FutureBuilder(
        future: AuthMethods().getCurrentUser(),
         builder: (context ,AsyncSnapshot<dynamic>snapshot){

            if(snapshot.hasData){
              return Home();
            }else{
              return SignIN();
            }
          }
       ),
    );
  }
}




