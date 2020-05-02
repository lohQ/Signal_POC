import 'package:cryptography/cryptography.dart';

class X3DH{
  static Future<SecretKey> senderGetSharedMasterSecret({
    PrivateKey keyA1,
    PrivateKey keyA2,
    PublicKey keyB1,
    PublicKey keyB2,
    PublicKey keyB3
  }) async {
    var dh1 = await (await x25519.sharedSecret(localPrivateKey: keyA1, remotePublicKey: keyB2)).extract();
    var dh2 = await (await x25519.sharedSecret(localPrivateKey: keyA2, remotePublicKey: keyB1)).extract();
    var dh3 = await (await x25519.sharedSecret(localPrivateKey: keyA2, remotePublicKey: keyB2)).extract();
    if(keyB3 != null){
      List<int> dh4;
      dh4 = await (await x25519.sharedSecret(localPrivateKey: keyA2, remotePublicKey: keyB3)).extract();
      return Hkdf(Hmac(sha256)).deriveKey(SecretKey(dh1+dh2+dh3+dh4), outputLength: 32);
    }else{
      return Hkdf(Hmac(sha256)).deriveKey(SecretKey(dh1+dh2+dh3), outputLength: 32);
    }
  }

  static Future<SecretKey> receiverGetMasterSecret({
    PrivateKey keyA1,
    PrivateKey keyA2,
    PrivateKey keyA3,
    PublicKey keyB1,
    PublicKey keyB2,
  }) async {
    var dh1 = await (await x25519.sharedSecret(localPrivateKey: keyA2, remotePublicKey: keyB1)).extract();
    var dh2 = await (await x25519.sharedSecret(localPrivateKey: keyA1, remotePublicKey: keyB2)).extract();
    var dh3 = await (await x25519.sharedSecret(localPrivateKey: keyA2, remotePublicKey: keyB2)).extract();
    if(keyA3 != null){
      List<int> dh4;
      dh4 = await (await x25519.sharedSecret(localPrivateKey: keyA3, remotePublicKey: keyB2)).extract();
      return Hkdf(Hmac(sha256)).deriveKey(SecretKey(dh1+dh2+dh3+dh4), outputLength: 32);
    }else{
      return Hkdf(Hmac(sha256)).deriveKey(SecretKey(dh1+dh2+dh3), outputLength: 32);
    }
  }

}