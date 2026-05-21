import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AuthGateView: View {
    @Environment(AppState.self) private var state
    @Environment(\.flakeTheme) private var theme

    @State private var currentNonce = ""

    var body: some View {
        ZStack {
            Color.flakeBG.ignoresSafeArea()
            OmbreBackground(style: .center)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                EyebrowLabel(text: "supabase connected", color: theme.g3)
                    .padding(.bottom, 14)

                (Text("flake\n").font(.display(64)) + Text("keeps score.").font(.display(54)).italic().foregroundStyle(theme.gradient2))
                    .foregroundStyle(.white)
                    .lineSpacing(-8)
                    .padding(.bottom, 14)

                Text("Sign in to save groups, moves, RSVPs, and points across the app and iMessage.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(state.authStatus == .signingIn)
                .padding(.bottom, 10)

                Button {
                    state.continueWithSampleData()
                } label: {
                    Text("continue with sample data")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(.plain)

                if let message = state.authErrorMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.bad)
                        .lineSpacing(2)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.bad.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                state.authErrorMessage = "Apple did not return an identity token."
                return
            }
            let displayName = credential.fullName.map {
                PersonNameComponentsFormatter().string(from: $0)
            } ?? ""
            Task {
                await state.signInWithApple(
                    identityToken: token,
                    nonce: currentNonce,
                    displayName: displayName
                )
            }
        case .failure(let error):
            state.authErrorMessage = error.localizedDescription
        }
    }
}

private enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate secure nonce.")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
