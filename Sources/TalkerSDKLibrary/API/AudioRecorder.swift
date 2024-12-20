//
//  AudioRecorder.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 22/07/24.
//

import Foundation
import AVFAudio
import WebRTC


public class AudioRecorder: NSObject, ObservableObject {
    
    var dataChannel: RTCDataChannel?

    @Published var isRecordingStart: Bool = false
    
    var audioEngine: AVAudioEngine!
    var inputNode: AVAudioInputNode!
    
    init(dataChannel: RTCDataChannel?) {
        self.dataChannel = dataChannel
    }
    func setupAudioEngine() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
    
        let format = inputNode.inputFormat(forBus: 0)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            self.convertAndProcessAudioBuffer(buffer: buffer, fromFormat: format, toFormat: desiredFormat)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    private func convertAndProcessAudioBuffer(buffer: AVAudioPCMBuffer, fromFormat: AVAudioFormat, toFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: fromFormat, to: toFormat) else {
            print("Failed to create AVAudioConverter")
            return
        }
        
        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: toFormat, frameCapacity: AVAudioFrameCount(toFormat.sampleRate * 0.1))!
        var error: NSError? = nil
        
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Error during conversion: \(error)")
            return
        }
        
        let channelData = convertedBuffer.int16ChannelData!
        let channelDataValue = channelData.pointee
        
        let data = Data(bytes: channelDataValue, count: Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size)
        // Here you can process the data or send it to a socket
        print("Converted audio buffer data: \(data)")
        self.sendData(data)
    }
    
    func getMinBufferSize(sampleRate: Double, channelCount: Int) -> Int {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channelCount))!
        let bufferSize = Int(audioFormat.streamDescription.pointee.mBytesPerFrame) * Int(audioFormat.streamDescription.pointee.mFramesPerPacket)
        return bufferSize
    }
    
    func startRecording() {
        self.setupAudioEngine()

        // Start the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }

    }
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    func sendData(_ data:Data){
        let rtcMessage = RTCDataBuffer(data: data, isBinary: true)
        self.dataChannel?.sendData(rtcMessage)
    }
}
