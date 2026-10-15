// Signs a release zip for Mara's updater: writes <zip>.sig, the Ed25519 signature in base64.
// The private key comes from MARA_UPDATE_PRIVATE_KEY (base64), a GitHub secret with a backup in
// the maintainer's Keychain. The public key must be the one the app carries, given as --expect,
// so a wrong secret fails the release instead of shipping updates nobody can install.
//
// Usage: MARA_UPDATE_PRIVATE_KEY=... swift scripts/sign-update.swift dist/Mara-AI-x.zip --expect <public key>
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("sign-update: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 4, arguments[2] == "--expect" else {
    fail("usage: swift scripts/sign-update.swift <zip> --expect <public key>")
}
guard let secret = ProcessInfo.processInfo.environment["MARA_UPDATE_PRIVATE_KEY"],
      let raw = Data(base64Encoded: secret.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
else { fail("MARA_UPDATE_PRIVATE_KEY is missing or not a base64 Ed25519 key") }

let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
guard publicKey == arguments[3] else {
    fail("the private key does not match the app's public key (\(publicKey) vs \(arguments[3]))")
}

let zip = URL(fileURLWithPath: arguments[1])
guard let data = try? Data(contentsOf: zip), let signature = try? key.signature(for: data) else {
    fail("could not read or sign \(zip.path)")
}
let output = zip.appendingPathExtension("sig")
do {
    try Data((signature.base64EncodedString() + "\n").utf8).write(to: output)
} catch {
    fail("could not write \(output.path): \(error.localizedDescription)")
}
print("Signed: \(output.path)")
