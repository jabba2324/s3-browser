import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        statusLabel.text = "Preparing files..."
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError("No items to share")
            return
        }

        let group = DispatchGroup()
        var savedFiles: [String] = []

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                group.enter()

                // Try to load as various types
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    loadAndSaveAttachment(attachment, typeIdentifier: UTType.image.identifier) { path in
                        if let path = path { savedFiles.append(path) }
                        group.leave()
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    loadAndSaveAttachment(attachment, typeIdentifier: UTType.movie.identifier) { path in
                        if let path = path { savedFiles.append(path) }
                        group.leave()
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    loadAndSaveAttachment(attachment, typeIdentifier: UTType.data.identifier) { path in
                        if let path = path { savedFiles.append(path) }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            if savedFiles.isEmpty {
                self?.showError("No compatible files found")
            } else {
                self?.openMainApp(with: savedFiles)
            }
        }
    }

    private func loadAndSaveAttachment(_ attachment: NSItemProvider, typeIdentifier: String, completion: @escaping (String?) -> Void) {
        attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] data, error in
            guard error == nil else {
                completion(nil)
                return
            }

            var fileData: Data?
            var filename: String = ""

            if let url = data as? URL {
                // File URL - use the actual filename from the URL
                fileData = try? Data(contentsOf: url)
                filename = url.lastPathComponent
            } else if let imageData = data as? Data {
                // Raw image data - try to determine format and create filename
                fileData = imageData
                let ext = self?.detectImageFormat(data: imageData) ?? "jpg"
                filename = "IMG_\(self?.generateTimestamp() ?? "unknown").\(ext)"
            } else if let image = data as? UIImage {
                // UIImage - convert to JPEG
                fileData = image.jpegData(compressionQuality: 0.9)
                filename = "IMG_\(self?.generateTimestamp() ?? "unknown").jpg"
            }

            // Use suggestedName if we still don't have a good filename
            if filename.isEmpty || filename == "/" {
                if let suggested = attachment.suggestedName, !suggested.isEmpty {
                    filename = suggested
                    // Add extension if missing
                    if !filename.contains(".") {
                        filename += self?.extensionForTypeIdentifier(typeIdentifier) ?? ""
                    }
                } else {
                    filename = "file_\(self?.generateTimestamp() ?? "unknown")\(self?.extensionForTypeIdentifier(typeIdentifier) ?? "")"
                }
            }

            guard let dataToSave = fileData else {
                completion(nil)
                return
            }

            // Save to shared App Group container
            if let savedPath = self?.saveToSharedContainer(data: dataToSave, filename: filename) {
                completion(savedPath)
            } else {
                completion(nil)
            }
        }
    }

    private func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func detectImageFormat(data: Data) -> String {
        if data.count < 8 { return "jpg" }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }
        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpg"
        }
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "gif"
        }
        // HEIC: check for ftyp box with heic/heix brand
        if data.count > 12 {
            let ftypRange = data[4..<8]
            if String(data: ftypRange, encoding: .ascii) == "ftyp" {
                let brandRange = data[8..<12]
                if let brand = String(data: brandRange, encoding: .ascii) {
                    if brand.hasPrefix("hei") || brand.hasPrefix("mif") {
                        return "heic"
                    }
                }
            }
        }

        return "jpg"
    }

    private func extensionForTypeIdentifier(_ typeIdentifier: String) -> String {
        if typeIdentifier.contains("image") {
            return ".jpg"
        } else if typeIdentifier.contains("movie") || typeIdentifier.contains("video") {
            return ".mov"
        } else if typeIdentifier.contains("pdf") {
            return ".pdf"
        }
        return ""
    }

    private func saveToSharedContainer(data: Data, filename: String) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.otacon.s3browser") else {
            return nil
        }

        let sharedFilesDir = containerURL.appendingPathComponent("SharedFiles", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: sharedFilesDir, withIntermediateDirectories: true)

        // Clean filename
        let safeFilename = filename.replacingOccurrences(of: "/", with: "_")
        let fileURL = sharedFilesDir.appendingPathComponent(safeFilename)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save file: \(error)")
            return nil
        }
    }

    private func openMainApp(with filePaths: [String]) {
        // Save file paths to UserDefaults for the main app to read
        if let userDefaults = UserDefaults(suiteName: "group.com.otacon.s3browser") {
            userDefaults.set(filePaths, forKey: "pending_shared_files")
            userDefaults.synchronize()
        }

        statusLabel.text = "Opening app..."

        // Open the main app via URL scheme
        let urlString = "s3browser://share"
        guard let url = URL(string: urlString) else {
            showError("Failed to open app")
            return
        }

        // Use the modern API to open URL
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while responder != nil {
            if responder?.responds(to: selector) == true {
                responder?.perform(selector, with: url, with: nil)
                break
            }
            responder = responder?.next
        }

        // Close extension after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.stopAnimating()
            self?.statusLabel.text = message
            self?.statusLabel.textColor = .systemRed

            // Add cancel button
            let cancelButton = UIButton(type: .system)
            cancelButton.setTitle("Cancel", for: .normal)
            cancelButton.addTarget(self, action: #selector(self?.cancelTapped), for: .touchUpInside)
            cancelButton.translatesAutoresizingMaskIntoConstraints = false
            self?.view.addSubview(cancelButton)

            if let label = self?.statusLabel {
                NSLayoutConstraint.activate([
                    cancelButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
                    cancelButton.centerXAnchor.constraint(equalTo: label.centerXAnchor),
                ])
            }
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
