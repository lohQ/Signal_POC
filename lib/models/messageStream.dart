import 'dart:async';

import 'message.dart';

class MessageStream {

  final _controller = StreamController<Message>.broadcast();

  Stream<Message> get stream => _controller.stream.asBroadcastStream();

  void sendMessage(Message message){
    _controller.sink.add(message);
  }

  void closeStream(){
    _controller.close();
  }

}