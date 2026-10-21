import 'dart:typed_data';

/// PBKDF2-HMAC-SHA256 (RFC 8018).
///
/// Les implémentations génériques en Dart pur allouent à chaque itération et
/// sont trop lentes pour un nombre d'itérations conforme aux recommandations
/// OWASP sur mobile. Ici, les états SHA-256 après les blocs ipad/opad sont
/// précalculés : chaque itération ne coûte que deux compressions, sans
/// allocation.
Uint8List pbkdf2HmacSha256(List<int> password, List<int> salt, int iterations, int keyLength) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
  if (keyLength < 1) throw ArgumentError.value(keyLength, 'keyLength');

  var key = password;
  if (key.length > _blockBytes) key = _sha256(_iv, 0, key);
  final ipad = Uint8List(_blockBytes)..fillRange(0, _blockBytes, 0x36);
  final opad = Uint8List(_blockBytes)..fillRange(0, _blockBytes, 0x5c);
  for (var i = 0; i < key.length; i++) {
    ipad[i] ^= key[i];
    opad[i] ^= key[i];
  }
  final innerState = Uint32List.fromList(_iv);
  final outerState = Uint32List.fromList(_iv);
  final w = Uint32List(64);
  _compress(innerState, _bytesToWords(ipad), w);
  _compress(outerState, _bytesToWords(opad), w);

  // Bloc d'une HMAC sur un message de 32 octets (un condensé) : les 8 premiers
  // mots reçoivent le condensé, le reste est le remplissage SHA-256 fixe.
  final block = Uint32List(16);
  final state = Uint32List(8);
  final u = Uint32List(8);
  final t = Uint32List(8);
  const paddedLengthBits = (_blockBytes + _digestBytes) * 8;

  final out = Uint8List(keyLength);
  for (var blockIndex = 1, offset = 0; offset < keyLength; blockIndex++, offset += _digestBytes) {
    // U1 = HMAC(P, S || INT(i))
    final saltAndIndex = [
      ...salt,
      for (final shift in [24, 16, 8, 0]) blockIndex >> shift & 0xff,
    ];
    final inner = _sha256(innerState, _blockBytes, saltAndIndex);
    final u1 = _sha256(outerState, _blockBytes, inner);
    for (var j = 0; j < 8; j++) {
      u[j] = _readWord(u1, j * 4);
      t[j] = u[j];
    }

    for (var n = 1; n < iterations; n++) {
      // Hachage interne : H(ipad || U).
      for (var j = 0; j < 8; j++) {
        block[j] = u[j];
      }
      block[8] = 0x80000000;
      block.fillRange(9, 15, 0);
      block[15] = paddedLengthBits;
      state.setAll(0, innerState);
      _compress(state, block, w);
      // Hachage externe : H(opad || interne).
      for (var j = 0; j < 8; j++) {
        block[j] = state[j];
      }
      block[8] = 0x80000000;
      block.fillRange(9, 15, 0);
      block[15] = paddedLengthBits;
      state.setAll(0, outerState);
      _compress(state, block, w);
      for (var j = 0; j < 8; j++) {
        u[j] = state[j];
        t[j] ^= state[j];
      }
    }

    for (var j = 0; j < 8 && offset + j * 4 < keyLength; j++) {
      for (var b = 0; b < 4 && offset + j * 4 + b < keyLength; b++) {
        out[offset + j * 4 + b] = t[j] >> (24 - 8 * b) & 0xff;
      }
    }
  }
  return out;
}

const _blockBytes = 64;
const _digestBytes = 32;

const _iv = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

/// SHA-256 de [message], en partant de [initial] après [prefixBytes] octets
/// déjà absorbés (un multiple de 64).
Uint8List _sha256(List<int> initial, int prefixBytes, List<int> message) {
  final totalBits = (prefixBytes + message.length) * 8;
  final paddedLength = (message.length + 9 + _blockBytes - 1) ~/ _blockBytes * _blockBytes;
  final data = Uint8List(paddedLength)
    ..setAll(0, message)
    ..[message.length] = 0x80;
  for (var i = 0; i < 8; i++) {
    data[paddedLength - 1 - i] = totalBits >> (8 * i) & 0xff;
  }
  final state = Uint32List.fromList(initial);
  final w = Uint32List(64);
  final block = Uint32List(16);
  for (var offset = 0; offset < paddedLength; offset += _blockBytes) {
    for (var j = 0; j < 16; j++) {
      block[j] = _readWord(data, offset + j * 4);
    }
    _compress(state, block, w);
  }
  final digest = Uint8List(_digestBytes);
  for (var j = 0; j < 8; j++) {
    for (var b = 0; b < 4; b++) {
      digest[j * 4 + b] = state[j] >> (24 - 8 * b) & 0xff;
    }
  }
  return digest;
}

int _readWord(List<int> bytes, int offset) =>
    bytes[offset] << 24 | bytes[offset + 1] << 16 | bytes[offset + 2] << 8 | bytes[offset + 3];

Uint32List _bytesToWords(Uint8List block) {
  final words = Uint32List(16);
  for (var j = 0; j < 16; j++) {
    words[j] = _readWord(block, j * 4);
  }
  return words;
}

int _rotr(int x, int n) => (x >> n | x << (32 - n)) & 0xffffffff;

/// Fonction de compression SHA-256 sur un bloc de 16 mots ; [w] est un
/// tampon de 64 mots réutilisé.
void _compress(Uint32List state, Uint32List block, Uint32List w) {
  for (var i = 0; i < 16; i++) {
    w[i] = block[i];
  }
  for (var i = 16; i < 64; i++) {
    final w15 = w[i - 15], w2 = w[i - 2];
    final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >> 3);
    final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >> 10);
    w[i] = w[i - 16] + s0 + w[i - 7] + s1;
  }
  var a = state[0], b = state[1], c = state[2], d = state[3];
  var e = state[4], f = state[5], g = state[6], h = state[7];
  for (var i = 0; i < 64; i++) {
    final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final ch = (e & f) ^ (~e & g);
    final t1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
    final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final maj = (a & b) ^ (a & c) ^ (b & c);
    final t2 = (s0 + maj) & 0xffffffff;
    h = g;
    g = f;
    f = e;
    e = (d + t1) & 0xffffffff;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & 0xffffffff;
  }
  state[0] += a;
  state[1] += b;
  state[2] += c;
  state[3] += d;
  state[4] += e;
  state[5] += f;
  state[6] += g;
  state[7] += h;
}
