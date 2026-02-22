import Testing
@testable import RoonKit

@Suite("VolumeControl Normalization Tests")
struct VolumeNormalizationTests {

    // MARK: - normalizedValue Tests

    @Test("normalizedValue: number type at minimum")
    func normalizedValueNumberMinimum() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 0,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("normalizedValue: number type at maximum")
    func normalizedValueNumberMaximum() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 100,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 1.0)
    }

    @Test("normalizedValue: number type at midpoint")
    func normalizedValueNumberMidpoint() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("normalizedValue: db type at minimum")
    func normalizedValueDbMinimum() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -80,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("normalizedValue: db type at maximum")
    func normalizedValueDbMaximum() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: 0,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.normalizedValue == 1.0)
    }

    @Test("normalizedValue: db type at midpoint")
    func normalizedValueDbMidpoint() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -40,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("normalizedValue: incremental type returns 0.0")
    func normalizedValueIncremental() {
        let volume = VolumeControl(
            type: .incremental,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("normalizedValue: max equals min returns 0.0")
    func normalizedValueMaxEqualMin() {
        let volume = VolumeControl(
            type: .number,
            min: 50,
            max: 50,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("normalizedValue: max less than min returns 0.0")
    func normalizedValueMaxLessThanMin() {
        let volume = VolumeControl(
            type: .number,
            min: 100,
            max: 50,
            value: 75,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("normalizedValue: negative db range")
    func normalizedValueNegativeDbRange() {
        let volume = VolumeControl(
            type: .db,
            min: -100,
            max: -10,
            value: -55,
            step: 1,
            isMuted: false
        )

        // (-55 - (-100)) / (-10 - (-100)) = 45 / 90 = 0.5
        #expect(volume.normalizedValue == 0.5)
    }

    @Test("normalizedValue: fractional result")
    func normalizedValueFractional() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 33,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.33)
    }

    // MARK: - denormalize Tests

    @Test("denormalize: number type at 0.0")
    func denormalizeNumberZero() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(0.0) == 0)
    }

    @Test("denormalize: number type at 1.0")
    func denormalizeNumberOne() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(1.0) == 100)
    }

    @Test("denormalize: number type at 0.5")
    func denormalizeNumberHalf() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(0.5) == 50)
    }

    @Test("denormalize: db type at 0.0")
    func denormalizeDbZero() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -40,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.denormalize(0.0) == -80)
    }

    @Test("denormalize: db type at 1.0")
    func denormalizeDbOne() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -40,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.denormalize(1.0) == 0)
    }

    @Test("denormalize: db type at 0.5")
    func denormalizeDbHalf() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -40,
            step: 0.5,
            isMuted: false
        )

        #expect(volume.denormalize(0.5) == -40)
    }

    @Test("denormalize: incremental type returns min")
    func denormalizeIncrementalReturnsMin() {
        let volume = VolumeControl(
            type: .incremental,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(0.0) == 0)
        #expect(volume.denormalize(0.5) == 0)
        #expect(volume.denormalize(1.0) == 0)
    }

    @Test("denormalize: negative db range")
    func denormalizeNegativeDbRange() {
        let volume = VolumeControl(
            type: .db,
            min: -100,
            max: -10,
            value: -55,
            step: 1,
            isMuted: false
        )

        // 0.0 → -100, 1.0 → -10, 0.5 → -55
        #expect(volume.denormalize(0.0) == -100)
        #expect(volume.denormalize(1.0) == -10)
        #expect(volume.denormalize(0.5) == -55)
    }

    @Test("denormalize: fractional normalized value")
    func denormalizeFractional() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(0.33) == 33)
        #expect(volume.denormalize(0.75) == 75)
    }

    // MARK: - Round-trip Tests

    @Test("round-trip: number type preserves value")
    func roundTripNumber() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 100,
            value: 50,
            step: 1,
            isMuted: false
        )

        let normalized = volume.normalizedValue
        let denormalized = volume.denormalize(normalized)

        #expect(denormalized == volume.value)
    }

    @Test("round-trip: db type preserves value")
    func roundTripDb() {
        let volume = VolumeControl(
            type: .db,
            min: -80,
            max: 0,
            value: -40,
            step: 0.5,
            isMuted: false
        )

        let normalized = volume.normalizedValue
        let denormalized = volume.denormalize(normalized)

        #expect(denormalized == volume.value)
    }

    @Test("round-trip: number type with negative values")
    func roundTripNumberNegative() {
        let volume = VolumeControl(
            type: .number,
            min: -100,
            max: 100,
            value: 0,
            step: 1,
            isMuted: false
        )

        let normalized = volume.normalizedValue
        let denormalized = volume.denormalize(normalized)

        #expect(denormalized == volume.value)
    }

    @Test("round-trip: db type with wide range")
    func roundTripDbWideRange() {
        let volume = VolumeControl(
            type: .db,
            min: -120,
            max: 20,
            value: -30,
            step: 0.1,
            isMuted: false
        )

        let normalized = volume.normalizedValue
        let denormalized = volume.denormalize(normalized)

        #expect(denormalized == volume.value)
    }

    // MARK: - Edge Cases with Parsing

    @Test("normalizedValue from parsed dictionary: number")
    func normalizedValueParsedNumber() {
        let dict: [String: Any] = [
            "type": "number",
            "min": 0.0,
            "max": 100.0,
            "value": 50.0,
            "step": 1.0
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("normalizedValue from parsed dictionary: db")
    func normalizedValueParsedDb() {
        let dict: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -40.0,
            "step": 0.5
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("normalizedValue from parsed dictionary: incremental")
    func normalizedValueParsedIncremental() {
        let dict: [String: Any] = [
            "type": "incremental",
            "min": 0,
            "max": 100,
            "value": 50,
            "step": 1
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.normalizedValue == 0.0)
    }

    @Test("denormalize from parsed dictionary: number")
    func denormalizeParsedNumber() {
        let dict: [String: Any] = [
            "type": "number",
            "min": 0,
            "max": 100,
            "value": 50,
            "step": 1
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.denormalize(0.5) == 50)
        #expect(volume.denormalize(0.0) == 0)
        #expect(volume.denormalize(1.0) == 100)
    }

    @Test("denormalize from parsed dictionary: db")
    func denormalizeParsedDb() {
        let dict: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -40.0,
            "step": 0.5
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.denormalize(0.5) == -40.0)
        #expect(volume.denormalize(0.0) == -80.0)
        #expect(volume.denormalize(1.0) == 0.0)
    }

    @Test("denormalize from parsed dictionary: incremental")
    func denormalizeParsedIncremental() {
        let dict: [String: Any] = [
            "type": "incremental",
            "min": 0,
            "max": 100,
            "value": 50,
            "step": 1
        ]

        let volume = VolumeControl(from: dict)!

        #expect(volume.denormalize(0.0) == 0)
        #expect(volume.denormalize(0.5) == 0)
        #expect(volume.denormalize(1.0) == 0)
    }

    // MARK: - Boundary Cases

    @Test("normalizedValue: value between min and max")
    func normalizedValueBetween() {
        let volume = VolumeControl(
            type: .number,
            min: 10,
            max: 90,
            value: 50,
            step: 1,
            isMuted: false
        )

        // (50 - 10) / (90 - 10) = 40 / 80 = 0.5
        #expect(volume.normalizedValue == 0.5)
    }

    @Test("denormalize: value with non-zero min")
    func denormalizeNonZeroMin() {
        let volume = VolumeControl(
            type: .number,
            min: 10,
            max: 90,
            value: 50,
            step: 1,
            isMuted: false
        )

        // 0.5 → 10 + 0.5 * (90 - 10) = 10 + 40 = 50
        #expect(volume.denormalize(0.5) == 50)
        #expect(volume.denormalize(0.0) == 10)
        #expect(volume.denormalize(1.0) == 90)
    }

    @Test("normalizedValue: very small range")
    func normalizedValueSmallRange() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 1,
            value: 0.5,
            step: 0.1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("denormalize: very small range")
    func denormalizeSmallRange() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 1,
            value: 0.5,
            step: 0.1,
            isMuted: false
        )

        #expect(volume.denormalize(0.5) == 0.5)
    }

    @Test("normalizedValue: very large range")
    func normalizedValueLargeRange() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 1000000,
            value: 500000,
            step: 1,
            isMuted: false
        )

        #expect(volume.normalizedValue == 0.5)
    }

    @Test("denormalize: very large range")
    func denormalizeLargeRange() {
        let volume = VolumeControl(
            type: .number,
            min: 0,
            max: 1000000,
            value: 500000,
            step: 1,
            isMuted: false
        )

        #expect(volume.denormalize(0.5) == 500000)
    }
}
