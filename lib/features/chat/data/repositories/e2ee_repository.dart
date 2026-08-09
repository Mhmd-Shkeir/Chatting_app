import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Basic E2EE MVP for 1:1 text messages — X25519 (ECDH) key exchange plus
/// AES-256-GCM authenticated encryption, both from the established
/// `cryptography` package (no hand-rolled crypto).
///
/// Design, deliberately minimal for a demo-scope MVP:
/// - Each device generates one long-lived X25519 keypair per account,
///   stored ONLY in flutter_secure_storage (Android Keystore / iOS
///   Keychain) — the private key never leaves the device, never touches
///   Firestore, and is not included in any backup this app controls.
/// - The public key alone is published to `users/{uid}.e2eePublicKey`
///   (not secret — this is exactly the "minimum public key info" the
///   other participant needs to encrypt to you).
/// - Two users derive the SAME shared secret via static-static ECDH (my
///   private key + their public key == their private key + my public key,
///   a property of Diffie-Hellman) — reused for the whole conversation.
///
/// Known limitations (by design, out of scope for this MVP — see the
/// project's status report for the full write-up): no forward secrecy (one
/// static shared secret per pair, not rotated per-message or per-session),
/// no key rotation, no multi-device support (a second device has no way to
/// learn the first device's private key, so it can't decrypt that
/// conversation's history), and no protection against a malicious server
/// swapping someone's published public key (no out-of-band verification /
/// safety-number comparison, unlike Signal). This is a working
/// demonstration of the encrypt-on-device/decrypt-on-device shape, not a
/// production-grade secure-messaging protocol.
class E2eeRepository {
  E2eeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? secureStorage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _secureStorage;
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  // In-memory only for this session — recomputed from the securely-stored
  // seed (and the other side's public key) on every cold start, never
  // written anywhere itself.
  SimpleKeyPair? _cachedKeyPair;
  final Map<String, SecretKey> _sharedSecretCache = {};

  String _privateKeySeedStorageKey(String uid) => 'e2ee_private_key_seed_$uid';

  Future<SimpleKeyPair> _ensureKeyPair() async {
    final cached = _cachedKeyPair;
    if (cached != null) return cached;

    final uid = _auth.currentUser!.uid;
    final storageKey = _privateKeySeedStorageKey(uid);
    final storedSeedB64 = await _secureStorage.read(key: storageKey);

    final SimpleKeyPair keyPair;
    if (storedSeedB64 != null) {
      keyPair = await _algorithm.newKeyPairFromSeed(base64Decode(storedSeedB64));
    } else {
      keyPair = await _algorithm.newKeyPair();
      final seed = await keyPair.extractPrivateKeyBytes();
      await _secureStorage.write(key: storageKey, value: base64Encode(seed));
    }
    _cachedKeyPair = keyPair;
    await _publishPublicKey(keyPair);
    return keyPair;
  }

  Future<void> _publishPublicKey(SimpleKeyPair keyPair) async {
    final uid = _auth.currentUser!.uid;
    final publicKey = await keyPair.extractPublicKey();
    await _firestore.collection('users').doc(uid).update({
      'e2eePublicKey': base64Encode(publicKey.bytes),
    });
  }

  /// Generates (if needed) and publishes this device's keypair — call once
  /// per session before any chat might need to encrypt/decrypt (see
  /// e2eeKeyTrackerProvider, watched at the app root once signed in).
  /// Idempotent: safe to call repeatedly.
  Future<void> ensureReady() => _ensureKeyPair();

  /// Whether [otherUid] has published a public key yet — gates the
  /// "Enable encryption" UI, since encrypting to someone who hasn't used
  /// E2EE yet on any device is impossible.
  Future<bool> hasPublishedKey(String otherUid) async {
    final doc = await _firestore.collection('users').doc(otherUid).get();
    return doc.data()?['e2eePublicKey'] != null;
  }

  Future<SecretKey> _sharedSecretWith(String otherUid) async {
    final cached = _sharedSecretCache[otherUid];
    if (cached != null) return cached;

    final keyPair = await _ensureKeyPair();
    final doc = await _firestore.collection('users').doc(otherUid).get();
    final otherPublicKeyB64 = doc.data()?['e2eePublicKey'] as String?;
    if (otherPublicKeyB64 == null) {
      throw StateError('This person has not enabled encryption on any device yet.');
    }
    final otherPublicKey = SimplePublicKey(base64Decode(otherPublicKeyB64), type: KeyPairType.x25519);
    final secret = await _algorithm.sharedSecretKey(keyPair: keyPair, remotePublicKey: otherPublicKey);
    _sharedSecretCache[otherUid] = secret;
    return secret;
  }

  /// Encrypts [plaintext] for [otherUid] and returns a single self-contained
  /// string — deliberately shaped to drop straight into a message's
  /// existing `text` field (nonce and MAC aren't secret, only the
  /// ciphertext needs the shared key to read), so no Firestore schema or
  /// security-rule changes were needed to support encrypted messages.
  Future<String> encryptFor(String otherUid, String plaintext) async {
    final secretKey = await _sharedSecretWith(otherUid);
    final box = await _cipher.encryptString(plaintext, secretKey: secretKey);
    return '${base64Encode(box.nonce)}.${base64Encode(box.mac.bytes)}.${base64Encode(box.cipherText)}';
  }

  /// Reverses [encryptFor]. Throws if the blob is malformed or the MAC
  /// doesn't verify (corruption or tampering) — callers should catch and
  /// show a fallback rather than crash (see MessageBubble's _EncryptedText).
  Future<String> decryptFrom(String otherUid, String blob) async {
    final parts = blob.split('.');
    if (parts.length != 3) {
      throw const FormatException('Malformed encrypted payload');
    }
    final secretKey = await _sharedSecretWith(otherUid);
    final box = SecretBox(
      base64Decode(parts[2]),
      nonce: base64Decode(parts[0]),
      mac: Mac(base64Decode(parts[1])),
    );
    return _cipher.decryptString(box, secretKey: secretKey);
  }
}
