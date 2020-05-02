import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:signal_poc/crypto/doubleRatchet.dart';
import 'package:signal_poc/crypto/x3dh.dart';
import 'package:signal_poc/models/keyStore.dart';
import 'package:signal_poc/models/message.dart';

class CryptoSession{

  final String selfId;
  KeyBundle oppBundle;
  KeyStore keyStore;
  DoubleRatchet doubleRatchet;

  // should be passed down from a higher level, but for simplicity here they are generetaed directly
  KeyPair selfIdentityKeyPair;
  KeyPair selfPreKeyPair;
  List<OneTimeKey> selfOneTimeKeyPairs;
  int _oneTimeKeyId;

  // cipher function is not working without it
  Nonce nonce;
  
  // for temporarily storing keys when received messages went out of order
  List<SecretKey> receivingMessageKeys;

  CryptoSession(this.selfId){
    keyStore = KeyStore();
    // this should be done in higher level
    if(keyStore.records.firstWhere((r)=>r.userId == selfId, orElse: ()=>null) == null){
      _createKeyStoreRecord();
      print("created record of $selfId at keyStore");
    }
    nonce = Nonce([1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4]);
  }

  void _createKeyStoreRecord() async {
    selfIdentityKeyPair = await x25519.newKeyPair();
    selfPreKeyPair = await x25519.newKeyPair();
    final preKeySignature = await ed25519.sign(selfPreKeyPair.publicKey.bytes, selfIdentityKeyPair);
    keyStore.records.add(
      KeyStoreRecord(
        userId: selfId,
        publicIdentityKey: selfIdentityKeyPair.publicKey,
        publicPreKey: selfPreKeyPair.publicKey,
        publicPreKeySignature: preKeySignature));
    final myRecord = keyStore.records.firstWhere((r)=>r.userId == selfId);
    selfOneTimeKeyPairs = List<OneTimeKey>();
    _oneTimeKeyId = 0;
    _generateOneTimeKeys(myRecord);
  }

  void _generateOneTimeKeys(KeyStoreRecord r) async {
    for(int i = 0; i < 10; i++){
      KeyPair kp = await x25519.newKeyPair();
      selfOneTimeKeyPairs.add(OneTimeKey.fromKeyPair(_oneTimeKeyId++, kp));
    }
    r.publicOneTimePreKeys = List.generate(
      selfOneTimeKeyPairs.length, 
      (i)=>OneTimeKey.fromPrivateOTK(selfOneTimeKeyPairs[i]));
  }

  // the initializer
  Future<Message> initializeSession(String oppId, Message m) async {
    oppBundle = keyStore.getKeyBundle(oppId);
    if(oppBundle != null){
      bool identityVerified = await _verifySignature(oppBundle);
      if(identityVerified){
        final ephemeralKey = await x25519.newKeyPair();
        m.header = Header(
          ephemeralKey: ephemeralKey.publicKey, 
          oneTimeKeyId: oppBundle.oneTimePreKey?.id);
        final rootKey = await X3DH.senderGetSharedMasterSecret(
          keyA1: selfIdentityKeyPair.privateKey,
          keyA2: ephemeralKey.privateKey,
          keyB1: oppBundle.publicIdentityKey,
          keyB2: oppBundle.publicPreKey,
          keyB3: oppBundle.oneTimePreKey?.publicOneTimeKey
        );
      // probably not the right way to calculate the chain key... 
        final sendingChainInput = await _hashChainInput(oppBundle.userId);
        final receivingChainInput = await _hashChainInput(selfId);
        doubleRatchet = await DoubleRatchet.create(rootKey,sendingChainInput,receivingChainInput);
        // to enforce the order of execution
        if(doubleRatchet.initialized()){
          return await encryptMessage(m);
        }
      }else{
        print("signature of user $oppId is not verified");
      }
    }else{
      print("user $oppId is not using this application!");
    }
    return null;
  }

  // the receiver
  Future<Message> initializeResponseSession(Message m) async {
    oppBundle = keyStore.getKeyBundle(m.senderId);
    bool identityVerified = await _verifySignature(oppBundle);
    if(identityVerified){
      OneTimeKey matchingOneTimeKey;
      if(m.header.oneTimeKeyId != null){
        matchingOneTimeKey = selfOneTimeKeyPairs.firstWhere((r)=>(r.id == m.header.oneTimeKeyId), orElse: ()=>null);
        if(matchingOneTimeKey == null){
          print("sender used invalid one time key! \nsession initialization aborded");
          return null;
        }else{
          selfOneTimeKeyPairs.remove(matchingOneTimeKey);
        }
      }
      final rootKey = await X3DH.receiverGetMasterSecret(
        keyA1: selfIdentityKeyPair.privateKey,
        keyA2: selfPreKeyPair.privateKey,
        keyA3: matchingOneTimeKey?.privateOneTimeKey,
        keyB1: oppBundle.publicIdentityKey,
        keyB2: m.header.ephemeralKey
      );
      // probably not the right way to calculate the chain key... 
      final sendingChainInput = await _hashChainInput(oppBundle.userId);
      final receivingChainInput = await _hashChainInput(selfId);
      doubleRatchet = await DoubleRatchet.create(rootKey, sendingChainInput, receivingChainInput);
      // to enforce the order of execution
      if(doubleRatchet.initialized()){
        return await decryptMessage(m);
      }
    }else{
      print("signature of user ${m.senderId} is not verified");
    }
    return null;
  }

  Future<List<int>> _hashChainInput(String input) async {
    var sink = sha256.newSink();
    sink.add(utf8.encode(input));
    sink.close();
    return sink.hash.bytes;
  }

  Future<bool> _verifySignature(KeyBundle r) async {
    // have to use xeddsa, but there is no available dart code for it
    // import c library later 
    return true;
  }

  Future<Message> encryptMessage(Message m) async {
    final mCopy = Message.copy(m);
    final ratchetKey = await x25519.newKeyPair();
    if(mCopy.header == null){mCopy.header = Header();}
    mCopy.header.ratchetKey = ratchetKey.publicKey;
    final messageKey = await doubleRatchet.sendingChainRatchetForward(ratchetKey.privateKey);
    final messageKeyBytes = await messageKey.extract();
    print("encryption message key: $messageKeyBytes");
    var cipher = CipherWithAppendedMac(aesCtr, Hmac(sha256));
    var encryptedMessage = await cipher.encrypt(mCopy.message, secretKey: messageKey, nonce: nonce);
    mCopy.message = encryptedMessage;
    return mCopy;
  }

  Future<Message> decryptMessage(Message m) async {
    final mCopy = Message.copy(m);
    final messageKey = await doubleRatchet.receivingChainRatchetForward(mCopy.header.ratchetKey);
    final messageKeyBytes = await messageKey.extract();
    print("decryption message key: $messageKeyBytes");
    var cipher = CipherWithAppendedMac(aesCtr, Hmac(sha256));
    try{
      var decryptedMessage = await cipher.decrypt(mCopy.message, secretKey: messageKey, nonce: nonce);
      mCopy.message = decryptedMessage;
      return mCopy;
    }catch(e){
      print("error decrypting message: $e");
      return null;
    }
  }

}
