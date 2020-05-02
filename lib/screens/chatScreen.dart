import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signal_poc/crypto/symmetricRatchet.dart';
import 'package:signal_poc/models/message.dart';
import 'package:signal_poc/models/messageStream.dart';
import 'package:signal_poc/models/user.dart';

class ChatScreen extends StatefulWidget{
  final User self;
  final User opp;
  final MessageStream messageStream;
  final Color color;
  ChatScreen({@required this.self, @required this.opp, @required this.messageStream, this.color});
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen>{

  List<Message> messageList;
  TextEditingController controller;
  SymmetricRatchetSession ratchetSession;

  @override
  void initState(){
    super.initState();
    messageList = List<Message>();
    controller = TextEditingController();
    ratchetSession = SymmetricRatchetSession(widget.self.id);
    widget.messageStream.stream
    .where((m)=>m.receiverId == widget.self.id)
    .listen((m){
      if(ratchetSession.doubleRatchet == null){
        ratchetSession.initializeResponseSession(m).then(
          (decrypted){
            if(decrypted == null){
              m.message = utf8.encode("failed to decrypt");
              _showDecryptedMessage(m);
            }else{
              _showDecryptedMessage(decrypted);
            }
          });
      }else{
        ratchetSession.decryptMessage(m).then(
          (decrypted){
            if(decrypted == null){
              m.message = utf8.encode("failed to decrypt");
              _showDecryptedMessage(m);
            }else{
              _showDecryptedMessage(decrypted);
            }
          });
      }
    });

  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Container(
      color: widget.color,
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[

            displayMessages(widget.self.id, messageList),

            Row(children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  ))
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: _sendMessage)
            ]),

          ],
      )
    );
  }

  void _sendMessage() {
    // if connected to internet
    final m = Message(
      message: utf8.encode(controller.text), 
      senderId: widget.self.id,
      receiverId: widget.opp.id,
      timestamp: DateTime.now());
    setState((){
      messageList.add(m);
      controller.text = "";
    });
    if(ratchetSession.doubleRatchet == null){
      ratchetSession.initializeSession(widget.opp.id, m).then(
        (encrypted){
          if(encrypted != null){_sendEncryptedMessage(encrypted);}
        });
    }else{
      ratchetSession.encryptMessage(m).then(
        (encrypted){
          if(encrypted != null){_sendEncryptedMessage(encrypted);}
        });
    }
    // else add it to pending-to-send queue
    // which subscribes to connecitivity provider 
    // and would send all the pending messages once connected again
  }

  Widget displayMessages(String senderId, List<Message> messageList){
    return Container(
      height: 200,
      child: ListView.builder(
        itemCount: messageList.length,
        itemBuilder: (context, i){
          String plainText;
          try{
            plainText = utf8.decode(messageList[i].message);
          }catch(e){
            plainText = "Error decoding message";
            print("error decoding message: $e");
          }
          bool isSentMessage = messageList[i].senderId==senderId;
          return Row(
            mainAxisAlignment: 
              isSentMessage ? 
              MainAxisAlignment.end : MainAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(5),
                color: Colors.white24,
                child: Text(plainText)
              )
            ],);
        },
      )
    );
    
  }

  void _sendEncryptedMessage(Message m){
    widget.messageStream.sendMessage(m);
    print("after encrypting: ${m.message.toString()}");
  }

  void _showDecryptedMessage(Message m){
    print("after decrypting: ${m.message.toString()}");
    setState((){
      messageList.add(m);
    });
  }

}

