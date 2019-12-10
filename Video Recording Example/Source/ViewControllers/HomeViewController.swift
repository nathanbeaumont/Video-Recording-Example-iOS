//
//  HomeViewController.swift
//  Video Recording Example
//
//  Created by Nathan Beaumont on 12/9/19.
//  Copyright © 2019 Nathan Beaumont. All rights reserved.
//

import AVFoundation
import AVKit
import MobileCoreServices
import UIKit

protocol HomeViewControllerProtocol: class {
    var audioDataOutput: AVCaptureAudioDataOutput { get set }
    var captureSession: AVCaptureSession { get set }
    var videoDataOutput: AVCaptureVideoDataOutput { get set }
    var isRecording: Bool { get set }

    func didFinishRecordingVideo(player: AVPlayer, videoFilePath: URL)
}

class HomeViewController: UIViewController {
    
    // MARK: Outlets
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var viewFinder: UIView!
    
    // MARK: Preview Stored Properties
    var captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: HomeViewControllerProtocol Properties
    var audioDataOutput = AVCaptureAudioDataOutput()
    var videoDataOutput = AVCaptureVideoDataOutput()
    var isRecording: Bool = false

    // MARK: Capture Stored Properties
    private var videoConnection: AVCaptureConnection?
    private let videoQueue = DispatchQueue(label: "com.catCall.cameraQueue", attributes: [], target: DispatchQueue.global(qos: .userInteractive))
    private var videoWriterDelegate: VideoWriterDelegate!
    private var recordedVideoURL: URL?


    // MARK: MARK Stored Properties
    private var playbackViewController = AVPlayerViewController()

    // MARK: Object Lifecycle Methods

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }

    func commonInit() {
        videoWriterDelegate = VideoWriterDelegate(homeViewController: self)
    }

    // MARK: ViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(videoEndedPlay), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        if let captureDevice = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                captureSession.addInput(input)
                
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                videoPreviewLayer?.frame = view.layer.bounds
                viewFinder.layer.addSublayer(videoPreviewLayer!)
                
                captureSession.startRunning()
            } catch {
                print(error)
            }
        }

        // Setup Microphone
        let microphone = AVCaptureDevice.default(for: AVMediaType.audio)
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone!)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
        } catch {
            print("Error setting device audio input: \(error)")
            return
        }

        recordButton.setTitle("Record Video!", for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if AVAudioSession.sharedInstance().responds(to: #selector(AVAudioSession.requestRecordPermission)) {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
    
    // MARK: Event Methods
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        captureSession.stopRunning()
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }

        do {
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(videoWriterDelegate, queue: videoQueue)
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
                videoConnection = videoDataOutput.connection(with: .video)
            }
        }

        do {
            audioDataOutput.setSampleBufferDelegate(videoWriterDelegate, queue: videoQueue)
            if captureSession.canAddOutput(audioDataOutput)  {
                captureSession.addOutput(audioDataOutput)
            }
        }

        if isRecording {
            videoWriterDelegate.stop()
            recordButton.setTitle("Record Video!", for: .normal)
            captureSession.stopRunning()
        } else {
            recordButton.setTitle("End Recording", for: .normal)
            captureSession.startRunning()
            videoWriterDelegate.start()
        }
    }

    @objc private func videoEndedPlay() {
        playbackViewController.player?.seek(to: CMTime.zero)
        playbackViewController.player?.play()
    }
}

extension HomeViewController: HomeViewControllerProtocol {

    func didFinishRecordingVideo(player: AVPlayer, videoFilePath: URL) {
        DispatchQueue.main.async {
            self.playbackViewController.player = player
            self.recordedVideoURL = videoFilePath
            self.present(self.playbackViewController, animated: true) {
                self.playbackViewController.player?.play()
            }
        }
    }
}
