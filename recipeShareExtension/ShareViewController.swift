import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private enum LaunchState {
        case preparing
        case opening
        case failed(String)
    }

    private let appGroupSuiteName = "group.sporkcast"
    private let sharedImportURLDefaultsKey = "share.recipeImportURL.v1"

    private var hasProcessedShare = false
    private var hasCompletedRequest = false
    private var importDeepLink: URL?

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let openButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyState(.preparing)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasProcessedShare else { return }
        hasProcessedShare = true

        Task { @MainActor in
            await processShareRequest()
        }
    }

    @MainActor
    private func processShareRequest() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            applyState(.failed("We couldn't read this share item."))
            return
        }

        guard let sharedURL = await firstSharedURL(in: items) else {
            applyState(.failed("Couldn't find a webpage URL to import."))
            return
        }

        persistSharedURL(sharedURL)
        importDeepLink = makeImportDeepLink(for: sharedURL)

        applyState(.opening)
        if await openContainingApp() {
            completeShareRequest()
        } else {
            applyState(.failed("Couldn't open Sporkast automatically. Tap below to try again."))
        }
    }

    private func firstSharedURL(in items: [NSExtensionItem]) async -> URL? {
        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if let url = await loadURL(from: provider) {
                    return url
                }
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let value = await loadItem(from: provider, typeIdentifier: UTType.url.identifier) {
            if let url = value as? URL, isWebURL(url) {
                return url
            }

            if let string = value as? String,
               let url = URL(string: string),
               isWebURL(url) {
                return url
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let value = await loadItem(from: provider, typeIdentifier: UTType.plainText.identifier),
           let string = value as? String,
           let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
           isWebURL(url) {
            return url
        }

        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private func makeImportDeepLink(for sourceURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "sporkcast"
        components.host = "import-recipe"
        components.queryItems = [URLQueryItem(name: "url", value: sourceURL.absoluteString)]
        return components.url
    }

    private func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func persistSharedURL(_ sharedURL: URL) {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(sharedURL.absoluteString, forKey: sharedImportURLDefaultsKey)
    }

    private func openContainingApp() async -> Bool {
        guard let targetURL = importDeepLink ?? URL(string: "sporkcast://import-recipe") else {
            return false
        }

        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                if #available(iOS 18.0, *) {
                    return await withCheckedContinuation { continuation in
                        application.open(targetURL, options: [:]) { success in
                            continuation.resume(returning: success)
                        }
                    }
                } else {
                    return application.perform(NSSelectorFromString("openURL:"), with: targetURL) != nil
                }
            }
            responder = current.next
        }

        return false
    }

    private func completeShareRequest() {
        guard !hasCompletedRequest else { return }
        hasCompletedRequest = true
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Add Recipe to Sporkast"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.configuration = .filled()
        openButton.configuration?.title = "Open Sporkast"
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(didTapOpenSporkast), for: .touchUpInside)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.configuration = .bordered()
        doneButton.configuration?.title = "Done"
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            activityIndicator,
            statusLabel,
            openButton,
            doneButton,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func applyState(_ state: LaunchState) {
        switch state {
        case .preparing:
            activityIndicator.startAnimating()
            statusLabel.text = "Preparing import…"
            openButton.isHidden = true
            doneButton.isHidden = true

        case .opening:
            activityIndicator.startAnimating()
            statusLabel.text = "Opening Sporkast…"
            openButton.isHidden = true
            doneButton.isHidden = true

        case let .failed(message):
            activityIndicator.stopAnimating()
            statusLabel.text = message
            openButton.isHidden = false
            doneButton.isHidden = false
        }
    }

    @objc
    private func didTapOpenSporkast() {
        Task { @MainActor in
            if await openContainingApp() {
                completeShareRequest()
            }
        }
    }

    @objc
    private func didTapDone() {
        completeShareRequest()
    }
}
