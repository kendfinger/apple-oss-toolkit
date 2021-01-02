//
//  fetch.swift
//
//
//  Created by Kenneth Endfinger on 12/31/20.
//

import ArgumentParser
import Foundation

struct FetchTool: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch Project Sources"
    )

    @Option(name: .shortAndLong, help: "Product Name")
    var product: String

    @Option(name: .shortAndLong, help: "Release Name")
    var release: String

    @Option(name: .shortAndLong, help: "Project Selections")
    var selection: [String] = []

    @Option(name: .shortAndLong, help: "Output Directory")
    var output: String = Process().currentDirectoryPath

    @Flag(name: .shortAndLong, help: "Extract Tarballs")
    var extract: Bool = false

    func run() throws {
        let lowerProductName = product.lowercased()
        let smooshedReleaseName = release.replacingOccurrences(of: ".", with: "")
        let moniker = "\(lowerProductName)-\(smooshedReleaseName)"
        let release = try OpenSourceClient.fetchReleaseDetails(moniker: moniker)

        let selectionInLower = selection.map {
            $0.lowercased()
        }

        let outputDirectoryURL = URL(fileURLWithPath: output)
        if !FileManager.default.fileExists(atPath: outputDirectoryURL.absoluteString) {
            try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        for project in release.projects.values {
            if !selection.isEmpty,
               !selectionInLower.contains(project.name!.lowercased()) {
                continue
            }
            let url = URL(string: project.url!)!

            print("* \(url.lastPathComponent)")

            let localURL = outputDirectoryURL.appendingPathComponent(url.lastPathComponent)

            print(localURL.absoluteString)

            let semaphore = DispatchSemaphore(value: 0)
            let task = URLSession.shared.downloadTask(with: url) { fileURL, _, error in
                if error != nil {
                    FetchTool.exit(withError: error)
                }

                do {
                    try FileManager.default.moveItem(at: fileURL!, to: localURL)
                } catch {
                    FetchTool.exit(withError: error)
                }
                semaphore.signal()
            }

            task.resume()
            semaphore.wait()
            if extract {
                try extractArchive(tar: localURL, into: outputDirectoryURL)
            }
        }

        FetchTool.exit()
    }
}
