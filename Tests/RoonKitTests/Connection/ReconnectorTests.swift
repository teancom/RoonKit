import Testing
@testable import RoonKit

@Suite("Reconnector Tests")
struct ReconnectorTests {

    @Test("First delay equals base delay plus jitter")
    func firstDelayEqualsBaseDelay() async {
        let config = ReconnectorConfig(
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 60.0,
            maxJitter: 0.0  // No jitter for predictable testing
        )
        let reconnector = Reconnector(config: config)

        let delay = await reconnector.nextDelay()

        #expect(delay == 1.0)
        #expect(await reconnector.currentAttempt == 1)
    }

    @Test("Delay doubles with each attempt")
    func delayDoublesWithEachAttempt() async {
        let config = ReconnectorConfig(
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 60.0,
            maxJitter: 0.0
        )
        let reconnector = Reconnector(config: config)

        let delay1 = await reconnector.nextDelay()
        let delay2 = await reconnector.nextDelay()
        let delay3 = await reconnector.nextDelay()
        let delay4 = await reconnector.nextDelay()

        #expect(delay1 == 1.0)
        #expect(delay2 == 2.0)
        #expect(delay3 == 4.0)
        #expect(delay4 == 8.0)
    }

    @Test("Delay caps at max delay")
    func delayCapsAtMaxDelay() async {
        let config = ReconnectorConfig(
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 5.0,
            maxJitter: 0.0
        )
        let reconnector = Reconnector(config: config)

        // 1, 2, 4, 5 (capped), 5 (capped)
        _ = await reconnector.nextDelay()  // 1
        _ = await reconnector.nextDelay()  // 2
        _ = await reconnector.nextDelay()  // 4
        let delay4 = await reconnector.nextDelay()  // should be 5 (capped from 8)
        let delay5 = await reconnector.nextDelay()  // should be 5 (capped from 16)

        #expect(delay4 == 5.0)
        #expect(delay5 == 5.0)
    }

    @Test("Jitter adds randomness within bounds")
    func jitterAddsRandomness() async {
        let config = ReconnectorConfig(
            baseDelay: 10.0,
            multiplier: 1.0,  // No growth, just test jitter
            maxDelay: 100.0,
            maxJitter: 0.1  // 10% jitter
        )
        let reconnector = Reconnector(config: config)

        let delay = await reconnector.nextDelay()

        // Delay should be between 10.0 and 11.0 (10% jitter)
        #expect(delay != nil)
        #expect(delay! >= 10.0)
        #expect(delay! <= 11.0)
    }

    @Test("Reset clears attempt count")
    func resetClearsAttemptCount() async {
        let config = ReconnectorConfig(
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 60.0,
            maxJitter: 0.0
        )
        let reconnector = Reconnector(config: config)

        _ = await reconnector.nextDelay()  // 1
        _ = await reconnector.nextDelay()  // 2
        _ = await reconnector.nextDelay()  // 4

        await reconnector.reset()

        let delayAfterReset = await reconnector.nextDelay()

        #expect(delayAfterReset == 1.0)
        #expect(await reconnector.currentAttempt == 1)
    }

    @Test("Returns nil when max attempts exceeded")
    func returnsNilWhenMaxAttemptsExceeded() async {
        let config = ReconnectorConfig(
            baseDelay: 1.0,
            multiplier: 2.0,
            maxDelay: 60.0,
            maxJitter: 0.0,
            maxAttempts: 3
        )
        let reconnector = Reconnector(config: config)

        let delay1 = await reconnector.nextDelay()
        let delay2 = await reconnector.nextDelay()
        let delay3 = await reconnector.nextDelay()
        let delay4 = await reconnector.nextDelay()

        #expect(delay1 != nil)
        #expect(delay2 != nil)
        #expect(delay3 != nil)
        #expect(delay4 == nil)
    }

    @Test("Default config matches design spec")
    func defaultConfigMatchesSpec() {
        let config = ReconnectorConfig.default

        #expect(config.baseDelay == 1.0)
        #expect(config.multiplier == 2.0)
        #expect(config.maxDelay == 60.0)
        #expect(config.maxJitter == 0.1)
        #expect(config.maxAttempts == nil)
    }

    @Test("Start and stop control isReconnecting state")
    func startAndStopControlState() async {
        let reconnector = Reconnector()

        #expect(await reconnector.isReconnecting == false)

        await reconnector.start()
        #expect(await reconnector.isReconnecting == true)

        await reconnector.stop()
        #expect(await reconnector.isReconnecting == false)
    }
}
