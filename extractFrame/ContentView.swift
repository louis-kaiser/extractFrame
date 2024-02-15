//
//  ContentView.swift
//  extractFrame
//
//  Created by Louis Kaiser on 14.02.24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraViewModel = CameraViewModel() // An instance of the camera view model
    
    var body: some View {
        VStack {
            if cameraViewModel.frames.count >= 30 {
                FramesView(cameraViewModel: cameraViewModel)
            } else {
                Text("Wait until all Frames are loded")
            }
        }
        .ignoresSafeArea(.all)
        .background(Color.black)
        .onAppear {
            cameraViewModel.startCapture()
        }
        
    }
}

struct FramesView: View {
    @ObservedObject var cameraViewModel: CameraViewModel // A reference to the camera view model
    
    var body: some View {
        ZStack {
            ForEach(0..<30) { index in
                Image(nsImage: cameraViewModel.frames[index])
                    .resizable()
                    .blendMode(.screen) // screen or lighten
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

import AVFoundation
import CoreImage

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
        let context = CIContext()
        
        // Apply threshold filter
        let thresholdFilter = CIFilter(name: "CIColorThreshold")!
        thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(0.7, forKey: "inputThreshold")
        guard let thresholdedImage = thresholdFilter.outputImage else { return }

        // Convert CIImage to CGImage
        guard let cgImage = context.createCGImage(thresholdedImage, from: thresholdedImage.extent) else { return }

        DispatchQueue.main.async {
            let newFrame = NSImage(cgImage: cgImage, size: NSSize(width: thresholdedImage.extent.width, height: thresholdedImage.extent.height))
            self.currentFrame = newFrame // Update the current frame
            self.frames.append(newFrame) // Append the new frame to the array
            if self.frames.count > 30 { // If the array has more than 30 frames, remove the first one
                self.frames.removeFirst()
            }
        }
    }

}
