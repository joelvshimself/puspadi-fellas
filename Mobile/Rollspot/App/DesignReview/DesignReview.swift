#if DEBUG
import SwiftUI

/// Debug-only design review: launch with `-designReview <screen>` to open one screen in a
/// fixed state, so iOS and Android can be screenshotted side by side against the Figma frames.
/// The same screen names exist on Android (`--es designReview <screen>`). Compiled out of release.
enum DesignReview: String, CaseIterable {
    case splash
    case welcome
    case emailFound, emailFoundFilled, emailFoundError
    case createPassword
    case name
    case mobility, mobilityFilled
    case allSet

    static let current: DesignReview? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-designReview"), index + 1 < args.count else { return nil }
        return DesignReview(rawValue: args[index + 1])
    }()

    static let sampleEmail = "name@gmail.com"
}

struct DesignReviewRoot: View {
    let screen: DesignReview

    var body: some View {
        switch screen {
        case .splash:
            SplashScreenView()
        case .welcome:
            login([])
        case .emailFound, .emailFoundFilled, .emailFoundError:
            login([.emailFound(DesignReview.sampleEmail)])
        case .createPassword:
            login([.createPassword(DesignReview.sampleEmail)])
        case .name:
            login([.createPassword(DesignReview.sampleEmail), .name])
        case .mobility:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility])
        case .mobilityFilled:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility], aids: ["Wheelchair"])
        case .allSet:
            login([.allSet])
        }
    }

    private func login(_ path: [AuthRoute], aids: Set<String> = []) -> some View {
        LoginView(onSuccess: {}, onCancel: {}, onExploreMalls: {}, initialPath: path, initialMobilityAids: aids)
    }
}
#endif
