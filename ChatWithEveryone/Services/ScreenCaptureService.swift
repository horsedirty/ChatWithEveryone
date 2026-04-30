import AppKit
import ScreenCaptureKit
import Combine

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let title: String
    let appName: String
    let icon: NSImage?
    let windowID: CGWindowID
    let scWindow: SCWindow
}

@MainActor
final class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    @Published var availableWindows: [WindowInfo] = []
    @Published var isCapturing = false

    func fetchWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            var results: [WindowInfo] = []
            for window in content.windows {
                guard let owningApp = window.owningApplication else { continue }
                guard window.frame.width > 100, window.frame.height > 100 else { continue }
                let icon = NSRunningApplication(processIdentifier: owningApp.processID)?.icon
                results.append(WindowInfo(
                    id: window.windowID,
                    title: window.title ?? "",
                    appName: owningApp.applicationName,
                    icon: icon,
                    windowID: window.windowID,
                    scWindow: window
                ))
            }
            availableWindows = results
        } catch {
            print("ScreenCaptureKit error: \(error)")
        }
    }

    func captureWindow(_ window: SCWindow) async -> NSImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        return await captureImage(with: filter, windowWidth: Int(window.frame.width), windowHeight: Int(window.frame.height))
    }

    func captureFullScreen() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            return await captureImage(with: filter, windowWidth: Int(display.width), windowHeight: Int(display.height))
        } catch {
            print("Capture error: \(error)")
            return nil
        }
    }

    private func captureImage(with filter: SCContentFilter, windowWidth: Int, windowHeight: Int) async -> NSImage? {
        let config = SCStreamConfiguration()
        config.width = windowWidth
        config.height = windowHeight
        config.showsCursor = true
        config.queueDepth = 1
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.scalesToFit = false

        return await withCheckedContinuation { continuation in
            let capturer = ScreenCapturer()
            capturer.capture(filter: filter, config: config) { image in
                continuation.resume(returning: image)
            }
        }
    }
}

private final class ScreenCapturer: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var completion: ((NSImage?) -> Void)?
    private var hasDelivered = false

    func capture(filter: SCContentFilter, config: SCStreamConfiguration, completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.stream = stream

        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        } catch {
            completion(nil)
            return
        }

        Task {
            do {
                try await stream.startCapture()
            } catch {
                completion(nil)
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !hasDelivered else { return }
        guard type == .screen else { return }

        hasDelivered = true

        Task { [weak self] in
            try? await self?.stream?.stopCapture()
        }

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            completion?(nil)
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        completion?(nsImage)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        if !hasDelivered {
            hasDelivered = true
            completion?(nil)
        }
    }
}
