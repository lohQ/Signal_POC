
import 'package:cryptography/cryptography.dart';
import 'package:signal_poc/crypto/keyDerievationChain.dart';

class DoubleRatchet{
  PrivateKey selfRatchet;
  PublicKey oppRatchet;
  SecretKey rootKey;
  KeyDerievationChain sendingChain;
  KeyDerievationChain receivingChain;
  bool _sentPublicRatchetKey;

  DoubleRatchet._internal(this.rootKey){
    _sentPublicRatchetKey = false;
  }

  static Future<DoubleRatchet> create(SecretKey root, List<int> sendingChainInput, List<int> receivingChainInput) async {
    final ratchet = DoubleRatchet._internal(root);
    ratchet.sendingChain = await KeyDerievationChain.create(root, sendingChainInput);
    ratchet.receivingChain = await KeyDerievationChain.create(root, receivingChainInput);
    return ratchet;
  }

  bool initialized(){
    return (rootKey != null) && (sendingChain != null) && (receivingChain != null);
  }

  Future<SecretKey> sendingChainRatchetForward(PrivateKey newSelfRatchet) async {
    if(newSelfRatchet != null){
      _sentPublicRatchetKey = true;
      selfRatchet = newSelfRatchet;
    }
    // if we have opposite side's public key and ...
    if(oppRatchet != null && newSelfRatchet != null){
      rootKey = await _calculateNewRootKey();
      // update the chain keys
      final newReceivingChainKey = await receivingChain.getNewChainKey(rootKey);
      final newSendingChainKey = await sendingChain.getNewChainKey(rootKey);
      receivingChain.resetChain(newReceivingChainKey);
      return await sendingChain.setNewChainKeyAndRatchetForward(newSendingChainKey);
    }else{
      return await sendingChain.ratchetForward();
    }
  }

  Future<SecretKey> receivingChainRatchetForward(PublicKey newOppRatchet) async {
    // if opposite side has our public key and ...
    if(newOppRatchet != null){
      oppRatchet = newOppRatchet;
    }
    if(_sentPublicRatchetKey && oppRatchet != null){
      rootKey = await _calculateNewRootKey();
      // update the chain keys
      final newReceivingChainKey = await receivingChain.getNewChainKey(rootKey);
      final newSendingChainKey = await sendingChain.getNewChainKey(rootKey);
      sendingChain.resetChain(newSendingChainKey);
      return await receivingChain.setNewChainKeyAndRatchetForward(newReceivingChainKey);
    }
    return await receivingChain.ratchetForward();
  }

  Future<SecretKey> _calculateNewRootKey() async {
    final ephemeralSecretBytes = await (await x25519.sharedSecret(localPrivateKey: selfRatchet, remotePublicKey: oppRatchet)).extract();
    print("ephemeralSecretBytes: $ephemeralSecretBytes");
    final rootKeyBytes = await rootKey.extract();
    return await Hkdf(Hmac(sha256)).deriveKey(SecretKey(rootKeyBytes+ephemeralSecretBytes), outputLength: 32);
  }

}
