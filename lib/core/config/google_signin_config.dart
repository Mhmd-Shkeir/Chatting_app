/// The OAuth "Web client ID" Firebase generates once Google is enabled as a
/// Sign-in method (Firebase Console -> Authentication -> Sign-in method ->
/// Google -> enable -> the "Web SDK configuration" section shows it, also
/// visible in Google Cloud Console -> APIs & Services -> Credentials as the
/// "Web client (auto created by Google Service)" entry).
///
/// This is NOT a secret — it identifies the project's OAuth client the same
/// way [imageKitPublicKey] identifies the ImageKit account, safe to embed.
/// It's required as `serverClientId` when initializing GoogleSignIn so the
/// ID token it issues has an audience Firebase can verify. Google Sign-In
/// on Android additionally needs this app's debug/release signing
/// certificate's SHA-1 fingerprint registered against the Android app in
/// Firebase Console (Project settings -> your Android app -> Add
/// fingerprint) — without that, native sign-in fails with a
/// DEVELOPER_ERROR / ApiException: 10 regardless of this constant.
const googleSignInServerClientId =
    '400283659453-p2vjersu34rf7qcm0cp7ljhtup4j20lb.apps.googleusercontent.com';
