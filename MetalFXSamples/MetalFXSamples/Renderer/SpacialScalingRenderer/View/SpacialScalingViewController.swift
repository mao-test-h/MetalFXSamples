import UIKit
import SwiftUI

class SpacialScalingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let viewController = UIHostingController(rootView: SpacialScalingContents())
        guard let contents = viewController.view else {
            return
        }

        view.addSubview(contents)
        contents.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contents.topAnchor.constraint(equalTo: view.topAnchor),
            contents.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contents.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contents.bottomAnchor)
        ])
    }
}
