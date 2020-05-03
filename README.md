# signal_poc

A simple Flutter project to try out basic end-to-end-encryption with Signal protocol. Uses the cryptography package (https://pub.dev/packages/cryptography). 

## features

#### Extended Triple Diffie Hellman Key Exchange
#### Double Ratchet algorithm

## note

The Signal protocol used in this project is not complete. 

#### verifying signature

This require xeddsa algorithm, which is currently not available in dart. However, as there is C code for it, could possibly just plug it in using dart:ffi. Or else could just rewrite the algorithm in dart. 

#### generating root key and chain key from shared master secret 

In the documentation of Signal Protocol, there is no clear description of how to generate root key from shared master secret, hence in this project it's simply rootKey = sharedMasterSecret. 

As for chain keys, when the first chain key is generated, Alice should already knows Bob's public ratchet key -- which I am not sure how it happens. So in this project the initial chain keys are simply generated using hashed userId as input. 

#### handling out of order messages

Due to the way 'instant messaging' is implemented in this project, it's quite hard to simulate such condition. 

#### correct message key format

The message key in Signal protocol is 80 bytes long. Here it is only 32 bytes. 

#### header encryption, AEAD, sesame algorithm

Ignored for simplicity.

