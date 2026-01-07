import AVFoundation
import Foundation

@MainActor
func printMetadata(for url: URL) async {
  // https://developer.apple.com/documentation/foundation/nslocale/preferredlanguages
  let preferred = Locale.preferredLanguages
  print("Preferred Languages:")
  print(preferred)
  print("\n")

  print("Reading file \(url.lastPathComponent)")
  print("\n")

  // Use async for safety (iOS 15+)
  let asset = AVURLAsset(url: url)
  do {
    // https://developer.apple.com/documentation/avfoundation/loading-media-data-asynchronously
    let preferred = Locale.preferredLanguages

    // https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading/load(_:isolation:)
    let (
      metadata,
      metadataFormats,
      chapterLocales
    ) = try await asset.load(
      .metadata,
      .availableMetadataFormats,
      .availableChapterLocales
    )

    print("Chapter Locales:")
    print(chapterLocales)
    print("\n")

    print("Metadata Formats:")
    print(metadataFormats)
    print("\n")

    for format in metadataFormats {
      let metadataItems = try await asset.loadMetadata(for: format)
      print("Metadata from format `\(format)`:")
      // print(metadataItems)
      // print("\n")
      for item in metadataItems {
        if let key = item.commonKey?.rawValue, let value = try await item.load(.value) {
          print("   \(key): \(value)")
        } else if let key = item.key as? String, let value = try await item.load(.value) {
          print("   \(key): \(value)")
        }
      }
      print("\n")
    }

    // https://developer.apple.com/documentation/avfoundation/avasset/loadchaptermetadatagroups(bestmatchingpreferredlanguages:completionhandler:)
    var metadataGroups = try await asset.loadChapterMetadataGroups(
      bestMatchingPreferredLanguages: preferred
    )

    // Fallback: anything is best when the alternative is nothing
    //           (audiobooks generally use a special 'und' locale)
    //           TODO: add 'und' to locales list above
    if metadataGroups.isEmpty, let firstLocale = chapterLocales.first {
      print("Fallback: first locale, `\(firstLocale.identifier)`\n\n")
      metadataGroups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: [
        firstLocale.identifier
      ])
    }

    if metadataGroups.isEmpty {
      print("no chapter data found")
      return
    }

    print("Metadata Groups:")
    print(metadataGroups)
    print("\n")

    print("Durations")
    for (index, group) in metadataGroups.enumerated() {
      let titleItems = AVMetadataItem.metadataItems(
        from: group.items, filteredByIdentifier: .commonIdentifierTitle)
      if let titleItem = titleItems.first,
        let title = try await titleItem.load(.value) as? String
      {
        let start = group.timeRange.start.seconds
        let duration = group.timeRange.duration.seconds
        //chapters.append(Chapter(title: title, startTime: start))
        print("   Chapter \(index + 1): \(title) [Start: \(start)s, Duration: \(duration)s]")
      }
    }
    print("\n")
  } catch {
    print("Error loading metadata: \(error)")
  }
}

let args = CommandLine.arguments.dropFirst()
guard !args.isEmpty else {
  print("Usage: swift \(CommandLine.arguments[0]) <file1.m4a> [file2.m4b] ...")
  exit(1)
}

await Task {
  for arg in args {
    let url = URL(fileURLWithPath: arg)
    if ["m4a", "m4b", "aac", "mp4", "m4v"].contains(url.pathExtension.lowercased()) {
      await printMetadata(for: url)
    } else {
      print("Skipping non-m4a/m4b file: \(arg)")
    }
  }
}.value
