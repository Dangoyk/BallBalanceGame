import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    enum Sound { case coin, hole, gameOver, wind }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var pool: [AVAudioPlayerNode] = []
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var poolIndex = 0

    private init() {
        for _ in 0..<6 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            pool.append(node)
        }
        try? engine.start()

        buffers[.coin]     = makeCoinSound()
        buffers[.hole]     = makeHoleSound()
        buffers[.gameOver] = makeGameOverSound()
        buffers[.wind]     = makeWindSound()
    }

    func play(_ sound: Sound) {
        guard engine.isRunning, let buf = buffers[sound] else { return }
        let node = pool[poolIndex % pool.count]
        poolIndex += 1
        node.stop()
        node.scheduleBuffer(buf)
        node.play()
    }

    // MARK: - Synthesis

    private func makeCoinSound() -> AVAudioPCMBuffer {
        let dur: Float = 0.20
        let buf = makeBuffer(dur)
        let sr = Float(44100)
        let d = buf.floatChannelData![0]
        for i in 0..<Int(buf.frameLength) {
            let t = Float(i) / sr
            let e = env(t, dur, atk: 0.003, rel: 0.09)
            let freq: Float = t < 0.10 ? 1047 : 1319
            d[i] = 0.42 * e * sin(2 * .pi * freq * t)
        }
        return buf
    }

    private func makeHoleSound() -> AVAudioPCMBuffer {
        let dur: Float = 0.55
        let buf = makeBuffer(dur)
        let sr = Float(44100)
        let d = buf.floatChannelData![0]
        for i in 0..<Int(buf.frameLength) {
            let t = Float(i) / sr
            let e = env(t, dur, atk: 0.01, rel: 0.25)
            let freq = 320.0 * pow(0.18, t / dur)
            d[i] = 0.52 * e * sin(2 * .pi * freq * t)
        }
        return buf
    }

    private func makeGameOverSound() -> AVAudioPCMBuffer {
        let dur: Float = 1.1
        let buf = makeBuffer(dur)
        let sr = Float(44100)
        let d = buf.floatChannelData![0]
        for i in 0..<Int(buf.frameLength) {
            let t = Float(i) / sr
            let e = env(t, dur, atk: 0.01, rel: 0.45)
            let slide = pow(0.4, t / dur)
            let s = sin(2 * .pi * 440 * slide * t)
                  + sin(2 * .pi * 349 * slide * t)
                  + sin(2 * .pi * 261 * slide * t)
            d[i] = 0.22 * e * s
        }
        return buf
    }

    private func makeWindSound() -> AVAudioPCMBuffer {
        let dur: Float = 0.9
        let buf = makeBuffer(dur)
        let sr = Float(44100)
        let d = buf.floatChannelData![0]
        for i in 0..<Int(buf.frameLength) {
            let t = Float(i) / sr
            let e = env(t, dur, atk: 0.28, rel: 0.30)
            d[i] = 0.14 * e * Float.random(in: -1...1)
        }
        return buf
    }

    private func makeBuffer(_ duration: Float) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(44100.0 * duration)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buf.frameLength = count
        return buf
    }

    private func env(_ t: Float, _ dur: Float, atk: Float, rel: Float) -> Float {
        let a = min(1.0, t / max(atk, 1e-4))
        let rs = dur - rel
        let r = t > rs ? max(0, 1 - (t - rs) / max(rel, 1e-4)) : 1.0
        return a * r
    }
}
