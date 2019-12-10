//
//  VideoWriterDelegate.swift
//  Video Recording Example
//
//  Created by Nathan Beaumont on 12/12/19.
//  Copyright © 2019 Nathan Beaumont. All rights reserved.
//

import AVFoundation
import AVKit
import Foundation

class VideoWriterDelegate: NSObject {

    // MARK: Static Properties
    private static var outputSettings: [String: Any] {
        return [AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 720,
                AVVideoHeightKey : 1280,
                AVVideoCompressionPropertiesKey :
                    [AVVideoAverageBitRateKey : 2300000],
                ]
    }

    // MARK: AV Writing Properties
    private var audioWriterInput: AVAssetWriterInput
    private var outputFileLocation: URL?
    private weak var homeViewController: HomeViewControllerProtocol!
    private var audioVideoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput
    private var sessionAtSourceTime: CMTime

    // MARK: Computed Properties
    private var canWrite: Bool {
        return homeViewController.isRecording && audioVideoWriter != nil && audioVideoWriter?.status == .writing
    }

    static private func videoFileLocation() -> URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)

        guard let documentDirectory: URL = urls.first else {
               fatalError("Document Error")
        }

        let videoOutputUrl = documentDirectory.appendingPathComponent("OutputVideo.mp4")
        if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputUrl.path)
            } catch {
                print("Unable to delete file: \(error) : \(#function).")
            }
        }

        return videoOutputUrl
    }

    // MARK: Object Lifecycle Methods

    init(homeViewController: HomeViewControllerProtocol) {
        self.homeViewController = homeViewController

        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
        audioWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: VideoWriterDelegate.outputSettings)
        videoWriterInput.expectsMediaDataInRealTime = true

        sessionAtSourceTime = CMTime.zero

        super.init()
    }
    
    private func setUpWriter() {
        do {
            let filePath = VideoWriterDelegate.videoFileLocation()
            outputFileLocation = filePath
            audioVideoWriter = try AVAssetWriter(outputURL: filePath, fileType: AVFileType.mov)

            if audioVideoWriter?.canAdd(videoWriterInput) ?? false {
                audioVideoWriter?.add(videoWriterInput)
                print("video input added")
            }

            if audioVideoWriter?.canAdd(audioWriterInput) ?? false {
                audioVideoWriter?.add(audioWriterInput)
                print("audio input added")
            }

            audioVideoWriter?.startWriting()
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }


    // MARK: Start recording
    public func start() {
        guard !homeViewController.isRecording else { return }
        homeViewController.isRecording = true
        setUpWriter()
        print(homeViewController.isRecording)
        print(audioVideoWriter ?? "")
        if audioVideoWriter?.status == .writing {
            print("status writing")
        } else if audioVideoWriter?.status == .failed {
            print("status failed")
        } else if audioVideoWriter?.status == .cancelled {
            print("status cancelled")
        } else if audioVideoWriter?.status == .unknown {
            print("status unknown")
        } else {
            print("status completed")
        }
    }

    // MARK: Stop recording
    public func stop() {
        guard self.homeViewController.isRecording else { return }
        self.homeViewController.isRecording = false
        self.videoWriterInput.markAsFinished()
        self.audioWriterInput.markAsFinished()
        print("marked as finished")
        self.homeViewController.captureSession.stopRunning()
        self.audioVideoWriter?.endSession(atSourceTime: self.sessionAtSourceTime)

        self.audioVideoWriter?.finishWriting { [weak self] in
            guard let filePath = self?.outputFileLocation?.path else {
                return
            }

            let videoURL = URL(fileURLWithPath: filePath)
            print("finished writing \(String(describing: videoURL.path))")
            print(FileManager.default.fileExists(atPath: videoURL.path))
            print(String(describing: self?.outputFileLocation!.absoluteString))

            let player = AVPlayer(url: videoURL)
            self?.homeViewController.didFinishRecordingVideo(player: player, videoFilePath: videoURL)
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoWriterDelegate: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let writable = canWrite
        if writable {
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            audioVideoWriter?.startSession(atSourceTime: sessionAtSourceTime)
            print("Writing")
        }

        if output == homeViewController?.videoDataOutput {
            connection.videoOrientation = .portrait
        }

        if writable, output == homeViewController.videoDataOutput, (videoWriterInput.isReadyForMoreMediaData) {
            videoWriterInput.append(sampleBuffer)
            print("video buffering")
        } else if writable, output == homeViewController.audioDataOutput, (audioWriterInput.isReadyForMoreMediaData) {
            audioWriterInput.append(sampleBuffer)
            print("audio buffering")
        }

    }
}
