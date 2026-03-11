import Sparkle
import Combine

/// Wraps SPUStandardUpdaterController as an ObservableObject so SwiftUI views
/// can reactively bind to update availability and button title.
final class SparkleUpdater: NSObject, ObservableObject {

    /// When false, Sparkle is busy (checking/downloading) — disable the button.
    @Published var canCheckForUpdates = false

    /// Reflects current update state for the menu item label.
    @Published var buttonTitle = "Check for Updates…"

    /// Lazy so `self` is a valid delegate when the controller initialises.
    private lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        // Accessing the lazy var triggers the SPU init with self as delegate.
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

// MARK: - SPUUpdaterDelegate

extension SparkleUpdater: SPUUpdaterDelegate {

    /// An update was found — offer to install.
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async { self.buttonTitle = "Install Update…" }
    }

    /// No update available — reset.
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async { self.buttonTitle = "Check for Updates…" }
    }

    /// Check failed (network error etc.) — reset.
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        DispatchQueue.main.async { self.buttonTitle = "Check for Updates…" }
    }
}
