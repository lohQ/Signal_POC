import 'dart:math';

import 'package:cryptography/cryptography.dart';

class Message{
  int id;
  List<int> message;
  DateTime timestamp;
  String senderId;
  String receiverId;
  Header header;
  Message({this.senderId, this.receiverId, this.message, this.timestamp, this.header}){
    id = Random().nextInt(1024);
  }
  static Message copy(Message m){
    final mCopy = Message(
      senderId: m.senderId,
      receiverId: m.receiverId,
      timestamp: m.timestamp,
      header: m.header,
      message: m.message
    );
    return mCopy;
  }
}

class Header{
  int oneTimeKeyId;
  PublicKey ephemeralKey;
  PublicKey ratchetKey;
  Header({this.oneTimeKeyId, this.ephemeralKey, this.ratchetKey});
}