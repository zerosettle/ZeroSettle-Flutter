import Flutter
import UIKit
import ZeroSettleKit
import SwiftUI

class ZSMigrateTipViewFlutterContainer: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private var hostingController: UIHostingController<ZSMigrateTipView>?

    init(frame: CGRect, arguments args: Any?) {
        containerView = UIView(frame: frame)
        super.init()

        // Parse creation arguments
        var backgroundColor = Color.black
        var userId = ""

        if let args = args as? [String: Any] {
            // Convert Flutter Color (ARGB int32) to SwiftUI Color
            if let colorInt = args["backgroundColor"] as? Int {
                let a = Double((colorInt >> 24) & 0xFF) / 255.0
                let r = Double((colorInt >> 16) & 0xFF) / 255.0
                let g = Double((colorInt >> 8) & 0xFF) / 255.0
                let b = Double(colorInt & 0xFF) / 255.0
                backgroundColor = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
            }
            userId = args["userId"] as? String ?? ""
        }

        // Create SwiftUI view
        let swiftUIView = ZSMigrateTipView(
            userId: userId,
            backgroundColor: backgroundColor
        )

        // Wrap in UIHostingController
        let hostingController = UIHostingController(rootView: swiftUIView)
        self.hostingController = hostingController

        // Configure hosting controller
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Add to container
        containerView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        // Attach to parent view controller
        attachHostingControllerIfPossible()
    }

    func view() -> UIView {
        return containerView
    }

    private func attachHostingControllerIfPossible() {
        guard let hc = hostingController else { return }

        // Find parent view controller via responder chain
        var responder: UIResponder? = containerView
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                if hc.parent !== viewController {
                    viewController.addChild(hc)
                    hc.didMove(toParent: viewController)
                }
                return
            }
            responder = nextResponder
        }
    }
}
