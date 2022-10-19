import UIKit
import SwiftUI

class SpacialScalingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let mainViewController = UIHostingController(rootView: MainView())
        guard let mainView = mainViewController.view else {
            return
        }

        view.addSubview(mainView)
        mainView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainView.topAnchor.constraint(equalTo: view.topAnchor),
            mainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: mainView.bottomAnchor)
        ])
    }
}
