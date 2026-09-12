import Foundation
import Observation
import AVFoundation
import UIKit

@MainActor
protocol ConnectionRuntime: AnyObject {
    var running: Bool { get }
    var status: String { get }
    var onChange: (() -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
final class InactiveConnectionRuntime: ConnectionRuntime {
    var running = false
    var status = "대기 중"
    var onChange: (() -> Void)?
    func start() {}
    func stop() {}
}

/// Holds audio only while a user-selected activity is shared. No recording or remote audio.
@MainActor @Observable
final class AudioConnectionRuntime: ConnectionRuntime {
    private(set) var status = "대기 중"
    private(set) var running = false
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var requested = false
    @ObservationIgnored private var interrupted = false

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            Task { @MainActor in self?.handleInterruption(type: type, options: options) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.requested else { return }
                self.player = nil; self.running = false; self.interrupted = false
                self.update("연결 유지 중단 · AIZU에서 다시 시도해 주세요")
            }
        })
    }

    func start() {
        requested = true
        if running, player?.isPlaying == true { return }
        // Do not compete with another app during an interruption.
        guard !interrupted else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let audio = try AVAudioPlayer(data: Self.silence())
            audio.numberOfLoops = -1
            guard audio.play() else { throw PresenceFailure.message("Audio playback could not start") }
            player = audio; running = true
            update("백그라운드 연결 유지 중")
        } catch {
            player?.stop(); player = nil; running = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            update("연결 유지 시작 안 됨 · AIZU를 열어 다시 시도해 주세요")
        }
    }

    func stop() {
        requested = false; interrupted = false
        guard player != nil || running || status != "대기 중" else { return }
        player?.stop(); player = nil; running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        update("대기 중")
    }

    private func handleInterruption(type: UInt, options: UInt) {
        guard requested else { return }
        if type == AVAudioSession.InterruptionType.began.rawValue {
            interrupted = true; running = false; player?.pause()
            update("다른 오디오 사용으로 연결 유지 일시 중단")
        } else if type == AVAudioSession.InterruptionType.ended.rawValue {
            interrupted = false
            if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                start()
            } else {
                update("연결 유지 중단 · AIZU에서 다시 시도해 주세요")
            }
        }
    }

    private func update(_ message: String) {
        status = message
        onChange?()
    }

    private static func silence() -> Data {
        var bytes = Data()
        func ascii(_ text: String) { bytes.append(contentsOf: text.utf8) }
        func word(_ value: UInt16) { bytes.append(UInt8(value & 255)); bytes.append(UInt8(value >> 8)) }
        func dword(_ value: UInt32) { word(UInt16(value & 65535)); word(UInt16(value >> 16)) }
        ascii("RIFF"); dword(16036); ascii("WAVEfmt "); dword(16)
        word(1); word(1); dword(8000); dword(16000); word(2); word(16)
        ascii("data"); dword(16000); bytes.append(Data(count: 16000))
        return bytes
    }
}
