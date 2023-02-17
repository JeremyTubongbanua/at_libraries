import 'dart:convert';
import 'dart:typed_data';

import 'package:at_chops/src/algorithm/aes_encryption_algo.dart';
import 'package:at_chops/src/algorithm/at_algorithm.dart';
import 'package:at_chops/src/algorithm/at_iv.dart';
import 'package:at_chops/src/algorithm/default_encryption_algo.dart';
import 'package:at_chops/src/algorithm/default_signing_algo.dart';
import 'package:at_chops/src/algorithm/pkam_signing_algo.dart';
import 'package:at_chops/src/at_chops_base.dart';
import 'package:at_chops/src/key/impl/aes_key.dart';
import 'package:at_chops/src/key/impl/at_chops_keys.dart';
import 'package:at_chops/src/key/impl/at_encryption_key_pair.dart';
import 'package:at_chops/src/key/key_type.dart';
import 'package:at_chops/src/metadata/at_signing_input.dart';
import 'package:at_chops/src/metadata/encryption_metadata.dart';
import 'package:at_chops/src/metadata/encryption_result.dart';
import 'package:at_chops/src/metadata/signing_metadata.dart';
import 'package:at_chops/src/metadata/signing_result.dart';
import 'package:at_commons/at_commons.dart';

class AtChopsImpl extends AtChops {
  AtChopsImpl(AtChopsKeys atChopsKeys) : super(atChopsKeys);

  @override
  AtEncryptionResult decryptBytes(
      Uint8List data, EncryptionKeyType encryptionKeyType,
      {AtEncryptionAlgorithm? encryptionAlgorithm,
      String? keyName,
      InitialisationVector? iv}) {
    try {
      encryptionAlgorithm ??=
          _getEncryptionAlgorithm(encryptionKeyType, keyName)!;
      final atEncryptionMetaData = AtEncryptionMetaData(
          encryptionAlgorithm.runtimeType.toString(), encryptionKeyType);
      atEncryptionMetaData.keyName = keyName;
      final atEncryptionResult = AtEncryptionResult()
        ..atEncryptionMetaData = atEncryptionMetaData
        ..atEncryptionResultType = AtEncryptionResultType.bytes;
      if (encryptionAlgorithm is SymmetricEncryptionAlgorithm) {
        atEncryptionResult.result = encryptionAlgorithm.decrypt(data, iv: iv!);
        atEncryptionMetaData.iv = iv;
      } else {
        atEncryptionResult.result = encryptionAlgorithm.decrypt(data);
      }
      return atEncryptionResult;
    } on Exception catch (e) {
      throw AtException(e.toString())
        ..stack(AtChainedException(
            Intent.decryptData,
            ExceptionScenario.decryptionFailed,
            'Failed to decrypt ${e.toString()}'));
    }
  }

  /// Decode the encrypted string to base64.
  /// Decode the encrypted byte to utf8 to support emoji chars.
  @override
  AtEncryptionResult decryptString(
      String data, EncryptionKeyType encryptionKeyType,
      {AtEncryptionAlgorithm? encryptionAlgorithm,
      String? keyName,
      InitialisationVector? iv}) {
    try {
      final decryptionResult = decryptBytes(
          base64Decode(data), encryptionKeyType,
          encryptionAlgorithm: encryptionAlgorithm, iv: iv);
      final atEncryptionResult = AtEncryptionResult()
        ..atEncryptionMetaData = decryptionResult.atEncryptionMetaData
        ..atEncryptionResultType = AtEncryptionResultType.string;
      atEncryptionResult.result = utf8.decode(decryptionResult.result);
      return atEncryptionResult;
    } on AtException {
      rethrow;
    }
  }

  @override
  AtEncryptionResult encryptBytes(
      Uint8List data, EncryptionKeyType encryptionKeyType,
      {AtEncryptionAlgorithm? encryptionAlgorithm,
      String? keyName,
      InitialisationVector? iv}) {
    try {
      encryptionAlgorithm ??=
          _getEncryptionAlgorithm(encryptionKeyType, keyName)!;
      final atEncryptionMetaData = AtEncryptionMetaData(
          encryptionAlgorithm.runtimeType.toString(), encryptionKeyType);
      atEncryptionMetaData.keyName = keyName;
      final atEncryptionResult = AtEncryptionResult()
        ..atEncryptionMetaData = atEncryptionMetaData
        ..atEncryptionResultType = AtEncryptionResultType.bytes;
      if (encryptionAlgorithm is SymmetricEncryptionAlgorithm) {
        atEncryptionResult.result = encryptionAlgorithm.encrypt(data, iv: iv!);
        atEncryptionMetaData.iv = iv;
      } else {
        atEncryptionResult.result = encryptionAlgorithm.encrypt(data);
      }
      return atEncryptionResult;
    } on Exception catch (e) {
      throw AtException(e.toString())
        ..stack(AtChainedException(
            Intent.decryptData,
            ExceptionScenario.decryptionFailed,
            'Failed to encrypt ${e.toString()}'));
    }
  }

  /// Encode the input string to utf8 to support emoji chars.
  /// Encode the encrypted bytes to base64.
  @override
  AtEncryptionResult encryptString(
      String data, EncryptionKeyType encryptionKeyType,
      {AtEncryptionAlgorithm? encryptionAlgorithm,
      String? keyName,
      InitialisationVector? iv}) {
    try {
      final utfEncodedData = utf8.encode(data);
      final encryptionResult = encryptBytes(
          Uint8List.fromList(utfEncodedData), encryptionKeyType,
          encryptionAlgorithm: encryptionAlgorithm, iv: iv);
      final atEncryptionResult = AtEncryptionResult()
        ..atEncryptionMetaData = encryptionResult.atEncryptionMetaData
        ..atEncryptionResultType = AtEncryptionResultType.string;
      atEncryptionResult.result = base64.encode(encryptionResult.result);
      return atEncryptionResult;
    } on AtException {
      rethrow;
    }
  }

  @override
  String hash(Uint8List signedData, AtHashingAlgorithm hashingAlgorithm) {
    return hashingAlgorithm.hash(signedData);
  }

  @override
  AtSigningResult signBytes(Uint8List data, SigningKeyType signingKeyType,
      {AtSigningAlgorithm? signingAlgorithm, int digestLength = 256}) {
    signingAlgorithm ??= _getSigningAlgorithm(signingKeyType)!;
    final atSigningMetadata = AtSigningMetaData(
        signingAlgorithm.runtimeType.toString(),
        signingKeyType,
        DateTime.now().toUtc(),
        DefaultSigningAlgo.generateDigestSpec(digestLength));
    final atSigningResult = AtSigningResult()
      ..atSigningMetaData = atSigningMetadata
      ..atSigningResultType = AtSigningResultType.bytes;
    atSigningResult.result = signingAlgorithm.sign(data, digestLength);
    return atSigningResult;
  }

  @override
  AtSigningResult verifySignatureBytes(
      Uint8List data, Uint8List signature, SigningKeyType signingKeyType,
      {AtSigningAlgorithm? signingAlgorithm, int digestLength = 256}) {
    signingAlgorithm ??= _getSigningAlgorithm(signingKeyType)!;
    final atSigningMetadata = AtSigningMetaData(
        signingAlgorithm.runtimeType.toString(),
        signingKeyType,
        DateTime.now().toUtc(),
        DefaultSigningAlgo.generateDigestSpec(digestLength));
    final atSigningResult = AtSigningResult()
      ..atSigningMetaData = atSigningMetadata
      ..atSigningResultType = AtSigningResultType.bool;
    atSigningResult.result = signingAlgorithm.verify(data, signature, 256);
    return atSigningResult;
  }

  @override
  //TODO: does this method need to have a fixed digest length of 256 as its already used somewhere
  AtSigningResult signString(String data, SigningKeyType signingKeyType,
      {AtSigningAlgorithm? signingAlgorithm}) {
    final signingResult = signBytes(
        utf8.encode(data) as Uint8List, signingKeyType,
        signingAlgorithm: signingAlgorithm);
    final atSigningMetadata = signingResult.atSigningMetaData;
    final atSigningResult = AtSigningResult()
      ..atSigningMetaData = atSigningMetadata
      ..atSigningResultType = AtSigningResultType.string;
    atSigningResult.result = base64Encode(signingResult.result);
    return atSigningResult;
  }

  @override
  AtSigningResult verifySignatureString(
      String data, String signature, SigningKeyType signingKeyType,
      {AtSigningAlgorithm? atSigningAlgorithm}) {
    final signingResult = verifySignatureBytes(
        utf8.encode(data) as Uint8List, base64Decode(signature), signingKeyType,
        signingAlgorithm: atSigningAlgorithm);
    final atSigningMetadata = signingResult.atSigningMetaData;
    final atSigningResult = AtSigningResult()
      ..atSigningMetaData = atSigningMetadata
      ..atSigningResultType = AtSigningResultType.bool;
    atSigningResult.result = signingResult.result;
    return atSigningResult;
  }

  @override
  AtSigningResult sign(AtSigningInput signingInput) {
    final dataBytes = utf8.encode(signingInput.plainText) as Uint8List;
    return signBytes(dataBytes, signingInput.signingKeyType, digestLength: signingInput.digestLength);
  }

  @override
  AtSigningResult verify(AtSigningInput verifyInput){
    return verifySignatureBytes(data, signature, signingKeyType);
  }

  AtEncryptionAlgorithm? _getEncryptionAlgorithm(
      EncryptionKeyType encryptionKeyType, String? keyName) {
    switch (encryptionKeyType) {
      case EncryptionKeyType.rsa2048:
        return DefaultEncryptionAlgo(
            _getEncryptionKeyPair(keyName)!, encryptionKeyType);
      case EncryptionKeyType.rsa4096:
        // TODO: Handle this case.
        break;
      case EncryptionKeyType.ecc:
        // TODO: Handle this case.
        break;
      case EncryptionKeyType.aes128:
        return AESEncryptionAlgo(atChopsKeys.symmetricKey! as AESKey);
      case EncryptionKeyType.aes256:
        return AESEncryptionAlgo(atChopsKeys.symmetricKey! as AESKey);
      default:
        throw Exception(
            'Cannot find encryption algorithm for encryption key type $encryptionKeyType');
    }
  }

  AtEncryptionKeyPair? _getEncryptionKeyPair(String? keyName) {
    if (keyName == null) {
      return atChopsKeys.atEncryptionKeyPair!;
    }
    // #TODO plugin implementation for different keyNames
    return null;
  }

  AtSigningAlgorithm? _getSigningAlgorithm(SigningKeyType signingKeyType) {
    switch (signingKeyType) {
      case SigningKeyType.pkamSha256:
        return PkamSigningAlgo(atChopsKeys.atPkamKeyPair!, signingKeyType);
      case SigningKeyType.signingSha256:
        return DefaultSigningAlgo(
            atChopsKeys.atEncryptionKeyPair!, signingKeyType);
      default:
        throw Exception(
            'Cannot find signing algorithm for signing key type $signingKeyType');
    }
  }
}
