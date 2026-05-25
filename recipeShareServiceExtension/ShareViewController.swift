import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private enum LaunchState {
        case preparing
        case opening
        case blockedSocialImport
        case failed(String)
    }

    private let appGroupSuiteName = "group.sporkcast"
    private let sharedImportURLDefaultsKey = "share.recipeImportURL.v1"
    private let socialRecipeImportFeatureAccessCacheKey = "features.recipeSocialImportPro.cached.v1"

    private var hasProcessedShare = false
    private var hasCompletedRequest = false
    private var importDeepLink: URL?

    private let cardView = UIView()
    private let heroIconView = UIImageView(image: UIImage(systemName: "sparkles"))
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let benefitStack = UIStackView()
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

        if isSupportedSocialRecipeURL(sharedURL) && !hasCachedSocialRecipeImportAccess {
            persistSharedURL(sharedURL)
            importDeepLink = makeImportDeepLink(for: sharedURL)
            applyState(.blockedSocialImport)
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
           let string = value as? String {
            if let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               isWebURL(url) {
                return url
            }

            if let url = extractFirstWebURL(from: string) {
                return url
            }
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

    private func extractFirstWebURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector
            .matches(in: text, options: [], range: range)
            .compactMap(\.url)
            .first(where: isWebURL)
    }

    private var hasCachedSocialRecipeImportAccess: Bool {
        UserDefaults(suiteName: appGroupSuiteName)?
            .object(forKey: socialRecipeImportFeatureAccessCacheKey) as? Bool ?? false
    }

    private func isSupportedSocialRecipeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return isInstagram(host) || isTikTok(host)
    }

    private func isInstagram(_ host: String) -> Bool {
        host == "instagram.com"
            || host == "www.instagram.com"
            || host.hasSuffix(".instagram.com")
    }

    private func isTikTok(_ host: String) -> Bool {
        host == "tiktok.com"
            || host == "www.tiktok.com"
            || host.hasSuffix(".tiktok.com")
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
        view.backgroundColor = .systemGroupedBackground

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerCurve = .continuous
        cardView.layer.cornerRadius = 28
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.10
        cardView.layer.shadowRadius = 22
        cardView.layer.shadowOffset = CGSize(width: 0, height: 12)

        heroIconView.translatesAutoresizingMaskIntoConstraints = false
        heroIconView.contentMode = .center
        heroIconView.tintColor = .systemOrange
        heroIconView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.14)
        heroIconView.layer.cornerCurve = .continuous
        heroIconView.layer.cornerRadius = 24
        heroIconView.preferredSymbolConfiguration = .init(pointSize: 28, weight: .semibold)

        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.text = "Sporkast Pro"
        eyebrowLabel.font = .preferredFont(forTextStyle: .caption1)
        eyebrowLabel.textColor = .secondaryLabel
        eyebrowLabel.textAlignment = .center
        eyebrowLabel.adjustsFontForContentSizeCategory = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Share to Sporkast"
        titleLabel.font = UIFontMetrics(forTextStyle: .title2)
            .scaledFont(for: .systemFont(ofSize: 22, weight: .bold))
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true

        benefitStack.translatesAutoresizingMaskIntoConstraints = false
        benefitStack.axis = .vertical
        benefitStack.spacing = 10
        benefitStack.isHidden = true
        benefitStack.addArrangedSubview(makeBenefitRow(symbol: "wand.and.sparkles", text: "Turn Reels and TikToks into editable recipes"))
        benefitStack.addArrangedSubview(makeBenefitRow(symbol: "text.badge.checkmark", text: "Capture ingredients, method, and serving details"))
        benefitStack.addArrangedSubview(makeBenefitRow(symbol: "photo.on.rectangle", text: "Save the original cover image with the recipe"))

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.configuration = .filled()
        openButton.configuration?.title = "Open Sporkast"
        openButton.configuration?.cornerStyle = .large
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(didTapOpenSporkast), for: .touchUpInside)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.configuration = .bordered()
        doneButton.configuration?.title = "Done"
        doneButton.configuration?.cornerStyle = .large
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            heroIconView,
            eyebrowLabel,
            titleLabel,
            activityIndicator,
            statusLabel,
            benefitStack,
            openButton,
            doneButton,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.setCustomSpacing(8, after: heroIconView)
        stack.setCustomSpacing(4, after: eyebrowLabel)
        stack.setCustomSpacing(18, after: statusLabel)
        stack.setCustomSpacing(18, after: benefitStack)

        cardView.addSubview(stack)
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),

            heroIconView.widthAnchor.constraint(equalToConstant: 72),
            heroIconView.heightAnchor.constraint(equalToConstant: 72),
            openButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            benefitStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func makeBenefitRow(symbol: String, text: String) -> UIView {
        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .systemOrange
        imageView.contentMode = .center
        imageView.preferredSymbolConfiguration = .init(pointSize: 17, weight: .semibold)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [imageView, label])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
        ])

        return row
    }

    private func applyState(_ state: LaunchState) {
        heroIconView.image = UIImage(systemName: "sparkles")
        heroIconView.tintColor = .systemOrange
        heroIconView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.14)
        eyebrowLabel.isHidden = true
        benefitStack.isHidden = true
        openButton.configuration?.title = "Open Sporkast"
        doneButton.configuration?.title = "Done"

        switch state {
        case .preparing:
            activityIndicator.startAnimating()
            titleLabel.text = "Share to Sporkast"
            statusLabel.text = "Preparing import…"
            openButton.isHidden = true
            doneButton.isHidden = true

        case .opening:
            activityIndicator.startAnimating()
            titleLabel.text = "Share to Sporkast"
            statusLabel.text = "Opening Sporkast…"
            openButton.isHidden = true
            doneButton.isHidden = true

        case .blockedSocialImport:
            activityIndicator.stopAnimating()
            eyebrowLabel.isHidden = false
            benefitStack.isHidden = false
            titleLabel.text = "Import reels with Pro"
            statusLabel.text = "Save the recipe from this TikTok or Instagram Reel without copying ingredients by hand, plus unlock organization, discovery, weather, widgets, and Calendar sync."
            openButton.configuration?.title = "See Sporkast Pro"
            doneButton.configuration?.title = "Not now"
            openButton.isHidden = false
            doneButton.isHidden = false

        case let .failed(message):
            activityIndicator.stopAnimating()
            heroIconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            heroIconView.tintColor = .systemRed
            heroIconView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
            titleLabel.text = "Import needs attention"
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
