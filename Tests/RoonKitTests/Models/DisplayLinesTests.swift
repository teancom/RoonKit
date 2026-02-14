import Testing
@testable import RoonKit

@Suite("DisplayLines Tests")
struct DisplayLinesTests {

    @Test("DisplayLines parses all three lines")
    func displayLinesParsesThreeLines() {
        let dict: [String: Any] = [
            "line1": "Song Title",
            "line2": "Artist Name",
            "line3": "Album Name"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines != nil)
        #expect(lines?.line1 == "Song Title")
        #expect(lines?.line2 == "Artist Name")
        #expect(lines?.line3 == "Album Name")
    }

    @Test("DisplayLines parses with only line1")
    func displayLinesParsesOneLine() {
        let dict: [String: Any] = [
            "line1": "Just A Title"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines != nil)
        #expect(lines?.line1 == "Just A Title")
        #expect(lines?.line2 == nil)
        #expect(lines?.line3 == nil)
    }

    @Test("DisplayLines parses with line1 and line2")
    func displayLinesParsesOneAndTwo() {
        let dict: [String: Any] = [
            "line1": "Title",
            "line2": "Artist"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines != nil)
        #expect(lines?.line1 == "Title")
        #expect(lines?.line2 == "Artist")
        #expect(lines?.line3 == nil)
    }

    @Test("DisplayLines returns nil for missing line1")
    func displayLinesMissingLine1() {
        let dict: [String: Any] = [
            "line2": "Artist",
            "line3": "Album"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines == nil)
    }

    @Test("DisplayLines with empty line1")
    func displayLinesEmptyLine1() {
        let dict: [String: Any] = [
            "line1": ""
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines != nil)
        #expect(lines?.line1 == "")
    }

    @Test("DisplayLines with special characters")
    func displayLinesSpecialCharacters() {
        let dict: [String: Any] = [
            "line1": "Song (feat. Artist) - Remix",
            "line2": "Various Artists & Collaborators",
            "line3": "Album [Deluxe Edition] — 2024"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines?.line1 == "Song (feat. Artist) - Remix")
        #expect(lines?.line2 == "Various Artists & Collaborators")
        #expect(lines?.line3 == "Album [Deluxe Edition] — 2024")
    }

    @Test("DisplayLines with unicode characters")
    func displayLinesUnicode() {
        let dict: [String: Any] = [
            "line1": "Très Belle Musique",
            "line2": "Artiste 中文",
            "line3": "Album 日本語"
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines?.line1 == "Très Belle Musique")
        #expect(lines?.line2 == "Artiste 中文")
        #expect(lines?.line3 == "Album 日本語")
    }

    @Test("DisplayLines equality")
    func displayLinesEquality() {
        let lines1 = DisplayLines(line1: "Title", line2: "Artist", line3: "Album")
        let lines2 = DisplayLines(line1: "Title", line2: "Artist", line3: "Album")
        let lines3 = DisplayLines(line1: "Title", line2: "Artist")

        #expect(lines1 == lines2)
        #expect(lines1 != lines3)
    }

    @Test("DisplayLines with very long strings")
    func displayLinesLongStrings() {
        let longLine = String(repeating: "A", count: 1000)
        let dict: [String: Any] = [
            "line1": longLine
        ]

        let lines = DisplayLines(from: dict)

        #expect(lines?.line1 == longLine)
        #expect(lines?.line1.count == 1000)
    }

    @Test("DisplayLines with empty dictionary")
    func displayLinesEmptyDict() {
        let dict: [String: Any] = [:]

        let lines = DisplayLines(from: dict)

        #expect(lines == nil)
    }

    @Test("DisplayLines initialization with values")
    func displayLinesInit() {
        let lines = DisplayLines(line1: "Title", line2: "Artist", line3: "Album")

        #expect(lines.line1 == "Title")
        #expect(lines.line2 == "Artist")
        #expect(lines.line3 == "Album")
    }

    @Test("DisplayLines initialization with nil values")
    func displayLinesInitNil() {
        let lines = DisplayLines(line1: "Title", line2: nil, line3: nil)

        #expect(lines.line1 == "Title")
        #expect(lines.line2 == nil)
        #expect(lines.line3 == nil)
    }
}

@Suite("NowPlaying Extended Tests")
struct NowPlayingExtendedTests {

    @Test("NowPlaying progress at start")
    func nowPlayingProgressAtStart() {
        let dict: [String: Any] = [
            "seek_position": 0.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 0.0)
        #expect(np?.remainingTime == 180.0)
    }

    @Test("NowPlaying progress at end")
    func nowPlayingProgressAtEnd() {
        let dict: [String: Any] = [
            "seek_position": 180.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 1.0)
        #expect(np?.remainingTime == 0.0)
    }

    @Test("NowPlaying progress beyond length clamped")
    func nowPlayingProgressBeyondLength() {
        let dict: [String: Any] = [
            "seek_position": 200.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 1.0) // Clamped to 1.0
        #expect(np?.remainingTime == 0.0)
    }

    @Test("NowPlaying progress negative clamped")
    func nowPlayingProgressNegative() {
        let dict: [String: Any] = [
            "seek_position": -10.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 0.0) // Clamped to 0.0
    }

    @Test("NowPlaying missing display lines returns nil")
    func nowPlayingMissingDisplayLines() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 180.0
        ]

        let np = NowPlaying(from: dict)

        #expect(np == nil)
    }

    @Test("NowPlaying missing one_line")
    func nowPlayingMissingOneLine() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 180.0,
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np == nil)
    }

    @Test("NowPlaying missing two_line")
    func nowPlayingMissingTwoLine() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np == nil)
    }

    @Test("NowPlaying missing three_line")
    func nowPlayingMissingThreeLine() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np == nil)
    }

    @Test("NowPlaying with nil lines inside three_line")
    func nowPlayingNilLinesInThreeLine() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title"] as [String: Any] // Missing line2 and line3
        ]

        let np = NowPlaying(from: dict)

        #expect(np != nil)
        #expect(np?.artist == nil)
        #expect(np?.album == nil)
    }

    @Test("NowPlaying equality")
    func nowPlayingEquality() {
        let np1 = NowPlaying(
            seekPosition: 60.0,
            length: 180.0,
            imageKey: "img-1",
            oneLine: DisplayLines(line1: "Title"),
            twoLine: DisplayLines(line1: "Title", line2: "Artist"),
            threeLine: DisplayLines(line1: "Title", line2: "Artist", line3: "Album")
        )

        let np2 = NowPlaying(
            seekPosition: 60.0,
            length: 180.0,
            imageKey: "img-1",
            oneLine: DisplayLines(line1: "Title"),
            twoLine: DisplayLines(line1: "Title", line2: "Artist"),
            threeLine: DisplayLines(line1: "Title", line2: "Artist", line3: "Album")
        )

        #expect(np1 == np2)
    }

    @Test("NowPlaying with image key")
    func nowPlayingWithImageKey() {
        let dict: [String: Any] = [
            "seek_position": 0.0,
            "length": 240.0,
            "image_key": "img-xyz-123",
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.imageKey == "img-xyz-123")
    }

    @Test("NowPlaying without image key")
    func nowPlayingWithoutImageKey() {
        let dict: [String: Any] = [
            "seek_position": 0.0,
            "length": 240.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.imageKey == nil)
    }

    @Test("NowPlaying with very short track")
    func nowPlayingVeryShort() {
        let dict: [String: Any] = [
            "seek_position": 0.5,
            "length": 1.0,
            "one_line": ["line1": "Beep"] as [String: Any],
            "two_line": ["line1": "Beep", "line2": "Sound"] as [String: Any],
            "three_line": ["line1": "Beep", "line2": "Sound", "line3": "Effect"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 0.5)
        #expect(np?.remainingTime == 0.5)
    }

    @Test("NowPlaying with very long track")
    func nowPlayingVeryLong() {
        let dict: [String: Any] = [
            "seek_position": 3600.0,
            "length": 36000.0,
            "one_line": ["line1": "Long"] as [String: Any],
            "two_line": ["line1": "Long", "line2": "Piece"] as [String: Any],
            "three_line": ["line1": "Long", "line2": "Piece", "line3": "Audio"] as [String: Any]
        ]

        let np = NowPlaying(from: dict)

        #expect(np?.progress == 0.1)
        #expect(np?.remainingTime == 32400.0)
    }
}
