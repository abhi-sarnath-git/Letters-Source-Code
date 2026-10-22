// Registration screens are explicitly local while SMS and the relying-party service are unconfigured.
import SwiftUI
import LocalAuthentication
import AuthenticationServices

struct AccountAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var section = ProcessInfo.processInfo.arguments.contains("--preview-passkey") ? 1 : 0
    @State private var country = "+44"
    @State private var phone = "7700 900123"
    @State private var biometricResult: String?
    @State private var checking = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                Label("LOCAL DESIGN PREVIEW",systemImage:"info.circle").font(.caption.bold()).foregroundStyle(LettersTheme.accent)
                Picker("Account setup",selection:$section) { Text("Invitation + phone").tag(0); Text("Passkey").tag(1) }.pickerStyle(.segmented)
                Image(systemName: section == 0 ? "envelope.badge.shield.half.filled" : "person.badge.key.fill")
                    .font(.system(size:48)).foregroundStyle(LettersTheme.accent).padding(.top,8)
                Text(section == 0 ? "An invitation. Your identity." : "Your key. Your device.").font(.largeTitle.bold())
                if section == 0 {
                    Label("1 · Scan or enter a Letterbox invitation",systemImage:"qrcode.viewfinder")
                    Text("Registration checks the invitation again before creating an account. Group invitations cannot create accounts.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    Label("2 · Confirm your phone number",systemImage:"iphone")
                    HStack {
                        TextField("Country code",text:$country).keyboardType(.phonePad).frame(width:80).accessibilityLabel("Country calling code")
                        TextField("National number",text:$phone).keyboardType(.phonePad).accessibilityLabel("National phone number")
                    }.padding(16).background(LettersTheme.surface,in:RoundedRectangle(cornerRadius:16))
                    Text("Fictional UK example. SMS is disabled; no number entered here is submitted or stored. Use international format without the national trunk zero.").font(.caption).foregroundStyle(LettersTheme.secondary)
                    Button("Send verification code · unavailable") {}.buttonStyle(.bordered).disabled(true)
                    Label("3 · Enter the one-time SMS code",systemImage:"number.square")
                    Text("A short-lived code proves access to the phone. Attempts and requests are limited. The invitation and OTP alone do not finish registration.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    Label("4 · Create your passkey",systemImage:"key.fill")
                    Text("Only after phone verification and server validation of the passkey does the account join the inviter's contacts.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                } else {
                    Label("Sign in with a passkey",systemImage:"person.badge.key").font(.title2)
                    Text("Face ID or Touch ID approves use of your passkey on your device. iOS may offer the device passcode. Letters does not receive your fingerprint or face scan.").foregroundStyle(LettersTheme.secondary)
                    Button("Create account passkey · unavailable") {}.buttonStyle(.borderedProminent).disabled(true)
                    Button("Sign in with passkey · unavailable") {}.buttonStyle(.bordered).disabled(true)
                    Text("A trusted HTTPS account service and associated domain are required. This build does not create a fake passkey or accept a local biometric result as server login.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    Divider()
                    Button(checking ? "Checking…" : "Try device biometrics locally") { testBiometrics() }.buttonStyle(.bordered).disabled(checking)
                    Text("Device capability demonstration only. It does not create an account, unlock message keys or authenticate to a server.").font(.caption).foregroundStyle(LettersTheme.secondary)
                    if let biometricResult { Text(biometricResult).foregroundStyle(LettersTheme.accent) }
                    Label("Encryption keys stay separate",systemImage:"lock.shield")
                    Text("An account passkey is not a message-decryption key. Message verification, key recovery and account recovery require separate flows; SMS alone must never recover encrypted history.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                }
            }.padding(24)
        }.background(OrbitBackdrop()).navigationTitle("Account access").navigationBarTitleDisplayMode(.inline)
    }
    private func testBiometrics() {
        let context=LAContext(); var error:NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,error:&error) else {
            biometricResult="Biometrics are unavailable or not enrolled on this device."; return
        }
        checking=true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,localizedReason:"Demonstrate Letters' local biometric check") { success,_ in
            Task { @MainActor in checking=false; biometricResult=success ? "Local biometric check passed. No account was signed in." : "Check cancelled or unsuccessful. No account was signed in." }
        }
    }
}

/// Native ceremony adapter. Call only with a server challenge from a configured trusted account service.
/// Returning a credential is NOT login success; the server must verify it and issue a session.
@MainActor final class LettersPasskeyCeremony: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum Failure: Error { case invalidConfiguration, busy, unsupportedResponse }
    private let rpID:String
    private let anchor:UIWindow
    private var pending:CheckedContinuation<[String:Any],Error>?
    private var controller:ASAuthorizationController?
    init(relyingPartyID:String, trustedOrigin:URL, anchor:UIWindow) throws {
        guard trustedOrigin.scheme == "https", trustedOrigin.host == relyingPartyID,
              trustedOrigin.user == nil, trustedOrigin.password == nil,
              trustedOrigin.query == nil, trustedOrigin.fragment == nil,
              trustedOrigin.path.isEmpty || trustedOrigin.path == "/" else { throw Failure.invalidConfiguration }
        rpID=relyingPartyID; self.anchor=anchor
    }
    func register(challenge:Data,userID:Data,userName:String) async throws -> [String:Any] {
        guard challenge.count == 32, !userID.isEmpty, userID.count <= 64 else { throw Failure.invalidConfiguration }
        let provider=ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier:rpID)
        let request=provider.createCredentialRegistrationRequest(challenge:challenge,name:userName,userID:userID)
        request.userVerificationPreference = .required
        return try await perform(request)
    }
    func authenticate(challenge:Data,credentialID:Data) async throws -> [String:Any] {
        guard challenge.count == 32, !credentialID.isEmpty else { throw Failure.invalidConfiguration }
        let provider=ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier:rpID)
        let request=provider.createCredentialAssertionRequest(challenge:challenge)
        request.userVerificationPreference = .required
        request.allowedCredentials=[ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID:credentialID)]
        return try await perform(request)
    }
    private func perform(_ request:ASAuthorizationRequest) async throws -> [String:Any] {
        guard pending == nil else { throw Failure.busy }
        return try await withCheckedThrowingContinuation { continuation in
            pending=continuation
            let controller=ASAuthorizationController(authorizationRequests:[request]); self.controller=controller
            controller.delegate=self; controller.presentationContextProvider=self; controller.performRequests()
        }
    }
    func presentationAnchor(for controller:ASAuthorizationController) -> ASPresentationAnchor { anchor }
    private func encoded(_ data:Data) -> String { data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"") }
    func authorizationController(controller:ASAuthorizationController,didCompleteWithAuthorization authorization:ASAuthorization) {
        let response:[String:Any]
        if let credential=authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
           let attestation=credential.rawAttestationObject {
            response=["id":encoded(credential.credentialID),"rawId":encoded(credential.credentialID),"type":"public-key",
                "response":["attestationObject":encoded(attestation),"clientDataJSON":encoded(credential.rawClientDataJSON)]]
        } else if let credential=authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            response=["id":encoded(credential.credentialID),"rawId":encoded(credential.credentialID),"type":"public-key",
                "response":["authenticatorData":encoded(credential.rawAuthenticatorData),"clientDataJSON":encoded(credential.rawClientDataJSON),
                    "signature":encoded(credential.signature),"userHandle":encoded(credential.userID)]]
        } else { finish(.failure(Failure.unsupportedResponse)); return }
        finish(.success(response))
    }
    func authorizationController(controller:ASAuthorizationController,didCompleteWithError error:Error) { finish(.failure(error)) }
    private func finish(_ result:Result<[String:Any],Error>) { let continuation=pending; pending=nil; controller=nil; continuation?.resume(with:result) }
}
