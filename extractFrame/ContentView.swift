//
//  ContentView.swift
//  extractFrame
//
//  Created by Louis Kaiser on 14.02.24.
//

import SwiftUI

struct ContentView: View {
    @State var showFrames = false // A state variable to control the view mode
    @ObservedObject var cameraViewModel = CameraViewModel() // An instance of the camera view model
    
    var body: some View {
        VStack {
            if showFrames {
                FramesView(cameraViewModel: cameraViewModel) // Show the frames view if the state is true
            } else {
                CameraView(cameraViewModel: cameraViewModel) // Show the camera view if the state is false
            }
            Button(action: {
                showFrames.toggle() // Toggle the state when the button is pressed
            }) {
                Text(showFrames ? "Show Camera" : "Show Frames") // Change the button text based on the state
            }
        }
        .padding()
    }
}

struct CameraView: View {
    @ObservedObject var cameraViewModel: CameraViewModel // A reference to the camera view model
    
    var body: some View {
        VStack {
            if let frame = cameraViewModel.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 400, height: 300)
            } else {
                Text("Waiting for camera feed...")
            }
        }
        .onAppear {
            cameraViewModel.startCapture()
        }
        .onDisappear {
            cameraViewModel.stopCapture()
        }
    }
}

struct FramesView: View {
    @ObservedObject var cameraViewModel: CameraViewModel // A reference to the camera view model
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(0..<30) { index in
                    Image(nsImage: cameraViewModel.frames[index])
                        .resizable()
                        .frame(width: 100, height: 100)
                        .border(Color.black)
                }
            }
        }
    }
}

import AVFoundation

class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    
    @Published var currentFrame: NSImage?
    @Published var frames: [NSImage] = [] // An array of frames instead of a single one
    
    override init() {
        super.init()
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device found")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraFrameQueue"))
            
            session = AVCaptureSession()
            session?.beginConfiguration()
            session?.addInput(input)
            session?.addOutput(output)
            session?.commitConfiguration()
        } catch {
            print("Error setting up capture session: \(error.localizedDescription)")
        }
    }
    
    func startCapture() {
        session?.startRunning()
    }
    
    func stopCapture() {
        session?.stopRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
        DispatchQueue.main.async {
            let newFrame = NSImage(cgImage: cgImage!, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
            self.currentFrame = newFrame // Update the current frame
            self.frames.append(newFrame) // Append the new frame to the array
            if self.frames.count > 30 { // If the array has more than 30 frames, remove the first one
                self.frames.removeFirst()
            }
        }
    }
}

