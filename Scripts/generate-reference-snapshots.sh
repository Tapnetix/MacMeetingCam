#!/bin/bash
# Scripts/generate-reference-snapshots.sh
# Renders wireframes/index.html to reference PNGs for visual regression tests

set -euo pipefail

OUTPUT_DIR="Tests/ReferenceSnapshots"
WIREFRAME="wireframes/index.html"

echo "=== Generating Reference Snapshots ==="

if [ ! -f "$WIREFRAME" ]; then
    echo "ERROR: Wireframe not found at $WIREFRAME"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Onboarding"

# Use swift script to render via WebKit
cat > /tmp/render-snapshots.swift << 'SWIFT_EOF'
import Foundation
import WebKit
import AppKit

// This script renders the wireframe HTML sections to PNG files
// Run with: swift /tmp/render-snapshots.swift <html-path> <output-dir>

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: render-snapshots <html-path> <output-dir>")
    exit(1)
}

let htmlPath = args[1]
let outputDir = args[2]
let htmlURL = URL(fileURLWithPath: htmlPath)

class SnapshotRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let outputDir: String
    let semaphore = DispatchSemaphore(value: 0)

    init(outputDir: String) {
        self.outputDir = outputDir
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        super.init()
        self.webView.navigationDelegate = self
    }

    func render(url: URL) {
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        semaphore.wait()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.captureSnapshots()
        }
    }

    func captureSnapshots() {
        let sections = [
            ("Settings_CameraTab", ".wireframe-section:nth-of-type(1) .macos-window"),
            ("Settings_BackgroundTab", ".wireframe-section:nth-of-type(2) .macos-window"),
            ("Settings_LoopTab", ".wireframe-section:nth-of-type(3) .macos-window"),
            ("Settings_HotkeysTab", ".wireframe-section:nth-of-type(4) .macos-window"),
            ("Settings_GeneralTab", ".wireframe-section:nth-of-type(5) .macos-window"),
            ("Menubar_Live", ".wireframe-section:nth-of-type(6) .popover:nth-of-type(1)"),
            ("FloatingPreview", ".wireframe-section:nth-of-type(7) .floating-preview"),
        ]

        let group = DispatchGroup()

        for (name, _) in sections {
            group.enter()
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, error in
                if let image = image {
                    let tiff = image.tiffRepresentation!
                    let bitmap = NSBitmapImageRep(data: tiff)!
                    let png = bitmap.representation(using: .png, properties: [:])!
                    let path = "\(self.outputDir)/\(name).png"
                    try? png.write(to: URL(fileURLWithPath: path))
                    print("Saved: \(path)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.semaphore.signal()
        }
    }
}

let renderer = SnapshotRenderer(outputDir: outputDir)
let app = NSApplication.shared
DispatchQueue.main.async {
    renderer.render(url: htmlURL)
}
app.run()
SWIFT_EOF

echo "Rendering wireframes..."
swift /tmp/render-snapshots.swift "$(pwd)/$WIREFRAME" "$(pwd)/$OUTPUT_DIR" || {
    echo "WARNING: Automated rendering failed. Please manually capture reference snapshots."
    echo "Open wireframes/index.html in a browser and screenshot each component."
}

echo ""
echo "Reference snapshots saved to $OUTPUT_DIR/"
