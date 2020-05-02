import 'package:flutter/material.dart';
import 'package:signal_poc/models/messageStream.dart';
import 'package:signal_poc/models/user.dart';

import 'chatScreen.dart';

class HomePage extends StatefulWidget{
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>{

  User alice = User("U01", "Alice");
  User bob = User("U02", "Bob");
  MessageStream stream;

  @override
  void initState(){
    super.initState();
    stream = MessageStream();
  }

  @override
  void dispose(){
    stream.closeStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text("Instant Messaging with Signal Protocol")),
        body: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ChatScreen(
                self: alice, 
                opp: bob, 
                messageStream: stream,
                color: Color.fromARGB(50, 100, 0, 0)),
              ChatScreen(
                self: bob, 
                opp: alice, 
                messageStream: stream,
                color: Color.fromARGB(50, 0, 0, 100)),
            ],)
      )
    );
  }
}