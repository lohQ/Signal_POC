import 'package:cryptography/cryptography.dart';

class KeyStore{
  List<KeyStoreRecord> records;  
  static final KeyStore _instance = KeyStore._internal();
  KeyStore._internal(){
    records = List<KeyStoreRecord>();
  }
  factory KeyStore(){
    return _instance;
  }
  KeyBundle getKeyBundle(String userId){
    KeyStoreRecord r = records.firstWhere((r)=>r.userId == userId, orElse: ()=>null);
    if(r == null){
      return null;
    }else{
      return KeyBundle.fromKeyStoreRecord(r);
    }
  }
}

class KeyBundle{
  String userId;
  PublicKey publicIdentityKey;
  PublicKey publicPreKey;
  Signature publicPreKeySignature;
  OneTimeKey oneTimePreKey;
  KeyBundle.fromKeyStoreRecord(KeyStoreRecord r){
    userId = r.userId;
    publicIdentityKey = r.publicIdentityKey;
    publicPreKey = r.publicPreKey;
    publicPreKeySignature = r.publicPreKeySignature;
    oneTimePreKey = (r.publicOneTimePreKeys.length > 0)
     ? r.publicOneTimePreKeys.removeAt(0)
     : null;
  }
}

class OneTimeKey{
  int id;
  PrivateKey privateOneTimeKey;
  PublicKey publicOneTimeKey;
  OneTimeKey.fromKeyPair(this.id, KeyPair kp){
    this.publicOneTimeKey = kp.publicKey;
    this.privateOneTimeKey = kp.privateKey;
  }
  OneTimeKey.fromPrivateOTK(OneTimeKey otk){
    this.id = otk.id;
    this.publicOneTimeKey = otk.publicOneTimeKey;
  }
}

class KeyStoreRecord{
  String userId;
  PublicKey publicIdentityKey;
  PublicKey publicPreKey;
  Signature publicPreKeySignature;
  List<OneTimeKey> publicOneTimePreKeys;
  KeyStoreRecord({this.userId, this.publicIdentityKey, this.publicPreKey, this.publicPreKeySignature, this.publicOneTimePreKeys});
}