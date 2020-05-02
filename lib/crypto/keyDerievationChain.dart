import 'package:cryptography/cryptography.dart';

class KeyDerievationChain{
  SecretKey chainKey;
  SecretKey messageKey;
  PrivateKey selfRatchetKey;
  PublicKey oppRatchetKey;
  List<int> initialInput;
  int _state;

  KeyDerievationChain._internal(this.initialInput){
    _state = 0;
  }

  static Future<KeyDerievationChain> create(SecretKey chainKey, List<int> input) async {
    final chain = KeyDerievationChain._internal(input);
    await chainKey.extract().then(
      (chainKeyBytes)async {
        chain.chainKey = await Hkdf(Hmac(sha256)).deriveKey(SecretKey(chainKeyBytes+input), outputLength: 32);
      });
    return chain;
  }

  Future<SecretKey> ratchetForward() async {
    // message key should be 80 bytes?
    final chainKeyListInt = await chainKey.extract();
    messageKey = await Hkdf(Hmac(sha256)).deriveKey(SecretKey(chainKeyListInt+[_state]), outputLength: 32);
    _state++;
    chainKey = await Hkdf(Hmac(sha256)).deriveKey(SecretKey(chainKeyListInt+[_state]), outputLength: 32);
    _state++;
    return messageKey;
  }

  // await this from outside 
  Future<SecretKey> getNewChainKey(SecretKey rootKey) async {
    final rootKeyBytes = await rootKey.extract();
    return await Hkdf(Hmac(sha256)).deriveKey(SecretKey(rootKeyBytes+initialInput), outputLength: 32);
  }

  Future<SecretKey> setNewChainKeyAndRatchetForward(SecretKey key) async {
    resetChain(key);    
    return await ratchetForward();
  }

  void resetChain(SecretKey key){
    chainKey = key;
    _state = 0;
  }

}