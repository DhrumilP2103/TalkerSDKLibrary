import Foundation
import WebRTC

protocol WebRTCClientDelegate: class {
    func webRTCClient(_ client: WebRTCClient, didGenerate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
}

final class WebRTCClient: NSObject {
    private var isPrintDebugData = false
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        //support all codec formats for encode and decode
//        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
        return RTCPeerConnectionFactory()
    }()

    weak var delegate: WebRTCClientDelegate?
    private let peerConnection: RTCPeerConnection

    // Accept video and audio from remote peer
    private let streamId = "KvsLocalMediaStream"
    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue
                                   /*kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue*/]
//    private var videoCapturer: RTCVideoCapturer?
//    private var localVideoTrack: RTCVideoTrack?
    var localAudioTrack: RTCAudioTrack?
//    private var remoteVideoTrack: RTCVideoTrack?
    private var remoteDataChannel: RTCDataChannel?
    private var constructedIceServers: [RTCIceServer]?

    private var peerConnectionFoundMap = [String: RTCPeerConnection]()
    private var pendingIceCandidatesMap = [String: Set<RTCIceCandidate>]()

    var isCreateDataChannel: Bool = true
    
    required init(iceServers: [RTCIceServer], isAudioOn: Bool) {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.bundlePolicy = .maxBundle
        config.keyType = .ECDSA
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .enabled

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)

        super.init()
//        configureAudioSession()

//        if (isAudioOn) {
        createLocalAudioStream()
//        }
//        createLocalVideoStream()
        peerConnection.delegate = self
    }

    func configureAudioSession(isAudioEnabled: Bool = false) {
        let audioSession = RTCAudioSession.sharedInstance()
        audioSession.isAudioEnabled = isAudioEnabled
        do {
            audioSession.lockForConfiguration()
            // NOTE : Can remove .defaultToSpeaker when not required.
            try
            audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with:[.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers, .allowAirPlay])
            try audioSession.setMode(AVAudioSession.Mode.default.rawValue)
            // NOTE : Can remove the following line when speaker not required.
            try audioSession.overrideOutputAudioPort(.speaker)
            
            //When passed in the options parameter of the setActive(_:options:) instance method, this option indicates that when your audio session deactivates, other audio sessions that had been interrupted by your session can return to their active state.
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            let audioSession1 = AVAudioSession.sharedInstance()
            try audioSession1.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession1.setActive(true)
            audioSession.unlockForConfiguration()
        } catch {
            print("audioSession error")
            if self.isPrintDebugData {
                print("audioSession error:::", error.localizedDescription)
            }
            audioSession.unlockForConfiguration()
        }
        
    }
    
    func shutdown() {
        peerConnection.close()
        
        if let stream = peerConnection.localStreams.first {
            localAudioTrack = nil
            //            localVideoTrack = nil
            //            remoteVideoTrack = nil
            peerConnection.remove(stream)
        }
        peerConnectionFoundMap.removeAll();
        pendingIceCandidatesMap.removeAll();
    }
    
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: mediaConstrains,
                                             optionalConstraints: nil)
        peerConnection.offer(for: constrains) { sdp, _ in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: mediaConstrains,
                                             optionalConstraints: nil)
        peerConnection.answer(for: constrains) { sdp, _ in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }
    
    func updatePeerConnectionAndHandleIceCandidates(clientId: String) {
        peerConnectionFoundMap[clientId] = peerConnection;
        handlePendingIceCandidates(clientId: clientId);
    }
    
    func handlePendingIceCandidates(clientId: String) {
        // Add any pending ICE candidates from the queue for the client ID
        if pendingIceCandidatesMap.index(forKey: clientId) != nil {
            var pendingIceCandidateListByClientId: Set<RTCIceCandidate> = pendingIceCandidatesMap[clientId]!;
            while !pendingIceCandidateListByClientId.isEmpty {
                let iceCandidate: RTCIceCandidate = pendingIceCandidateListByClientId.popFirst()!
                let peerConnectionCurrent : RTCPeerConnection = peerConnectionFoundMap[clientId]!
                peerConnectionCurrent.add(iceCandidate)
                if self.isPrintDebugData {
                    print("Added ice candidate after SDP exchange::: \(iceCandidate.sdp)");
                } else {
                    print("Added ice candidate after SDP exchange");
                }
            }
            // After sending pending ICE candidates, the client ID's peer connection need not be tracked
            pendingIceCandidatesMap.removeValue(forKey: clientId)
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, clientId: String, completion: @escaping (Error?) -> Void) {
        peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
        if remoteSdp.type == RTCSdpType.answer {
            if self.isPrintDebugData {
                print("Received answer for client ID::: \(clientId)")
            } else {
                print("Received answer for client ID")
            }
            updatePeerConnectionAndHandleIceCandidates(clientId: clientId)
        }
    }
    
    // SDP exchange Precess
    func checkAndAddIceCandidate(remoteCandidate: RTCIceCandidate, clientId: String) {
        // if answer/offer is not received, it means peer connection is not found. Hold the received ICE candidates in the map.
        if peerConnectionFoundMap.index(forKey: clientId) == nil {
            if self.isPrintDebugData {
                print("SDP exchange not completed yet. Adding candidate: \(remoteCandidate.sdp) to pending queue")
            } else {
                print("SDP exchange not completed yet. Adding candidate:  to pending queue")
            }
            // If the entry for the client ID already exists (in case of subsequent ICE candidates), update the queue
            if pendingIceCandidatesMap.index(forKey: clientId) != nil {
                var pendingIceCandidateListByClientId: Set<RTCIceCandidate> = pendingIceCandidatesMap[clientId]!
                pendingIceCandidateListByClientId.insert(remoteCandidate)
                pendingIceCandidatesMap[clientId] = pendingIceCandidateListByClientId
            }
            // If the first ICE candidate before peer connection is received, add entry to map and ICE candidate to a queue
            else {
                var pendingIceCandidateListByClientId = Set<RTCIceCandidate>()
                pendingIceCandidateListByClientId.insert(remoteCandidate)
                pendingIceCandidatesMap[clientId] = pendingIceCandidateListByClientId
            }
        }
        // This is the case where peer connection is established and ICE candidates are received for the established connection
        else {
//            print("Peer connection found already")
            // Remote sent us ICE candidates, add to local peer connection
            let peerConnectionCurrent : RTCPeerConnection = peerConnectionFoundMap[clientId]!
            peerConnectionCurrent.add(remoteCandidate);
            
            if self.isPrintDebugData {
                print("Added ice candidate::: \(remoteCandidate.sdp)");
            } else {
                print("Added ice candidate");
            }
        }
    }
    
    func set(remoteCandidate: RTCIceCandidate, clientId: String) {
        checkAndAddIceCandidate(remoteCandidate: remoteCandidate, clientId: clientId)
    }
    
    private func createLocalAudioStream() {
        localAudioTrack = createAudioTrack()
        if let localAudioTrack  = localAudioTrack {
            peerConnection.add(localAudioTrack, streamIds: [streamId])
            let audioTracks = peerConnection.transceivers.compactMap { $0.sender.track as? RTCAudioTrack }
            audioTracks.forEach { $0.isEnabled = true }
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let mediaConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: mediaConstraints)
        return WebRTCClient.factory.audioTrack(with: audioSource, trackId: "KvsAudioTrack")
    }
}
//MARK: - Peer Connection Delegate
extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func createDataChannelForAudio() -> RTCDataChannel {
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = false  // Set to true if you want the messages to be received in the same order they were sent
        dataChannelConfig.maxRetransmits = 30  // Set the maximum number of retransmissions
        
        let channelName = "\(UserDefaults.standard.value(forKey: "channelName") ?? "")"
        if let dataChannel = peerConnection.dataChannel(forLabel: channelName, configuration: dataChannelConfig) {
            dataChannel.delegate = self
            self.remoteDataChannel = dataChannel
            return dataChannel
        }
        return self.remoteDataChannel!
    }
    
    func createDataChannel() {
//        print("Call createDataChannel Complated")
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = false  // Set to true if you want the messages to be received in the same order they were sent
        dataChannelConfig.maxRetransmits = 30  // Set the maximum number of retransmissions
        
        let channelName = "\(UserDefaults.standard.value(forKey: "channelName") ?? "")"
        if let dataChannel = peerConnection.dataChannel(forLabel: channelName, configuration: dataChannelConfig) {
            dataChannel.delegate = self
            self.remoteDataChannel = dataChannel
        }
    }
    
    // MARK: DataChannel Event
    func sendMessge(message: String){
        if let _dataChannel = self.remoteDataChannel {
            if _dataChannel.readyState == .open {
                let buffer = RTCDataBuffer(data: message.data(using: String.Encoding.utf8)!, isBinary: false)
                _dataChannel.sendData(buffer)
            } else {
                print("data channel is not ready state")
            }
        } else{
            print("no data channel")
        }
    }
    
    func peerConnection(_: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        if self.isPrintDebugData {
            debugPrint("peerConnection stateChanged::: \(stateChanged.rawValue)")
        } else {
            debugPrint("peerConnection stateChanged")
        }
        if self.isCreateDataChannel {
            self.createDataChannel()
            self.isCreateDataChannel = false
        }
    }
    
    func peerConnection(_: RTCPeerConnection, didAdd _: RTCMediaStream) {
        debugPrint("peerConnection did add stream")
    }
    
    func peerConnection(_: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        if self.isPrintDebugData {
            debugPrint("peerConnection didRemove stream::: \(stream)")
        } else {
            debugPrint("peerConnection didRemove stream")
        }
    }
    
    func peerConnectionShouldNegotiate(_: RTCPeerConnection) {
        debugPrint("peerConnectionShouldNegotiate")
    }
    
    func peerConnection(_: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        if self.isPrintDebugData {
            debugPrint("peerConnection RTCIceGatheringState::: \(newState)")
        } else {
            debugPrint("peerConnection RTCIceGatheringState")
        }
    }
    
    func peerConnection(_: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if self.isPrintDebugData {
            debugPrint("peerConnection RTCIceConnectionState::: \(newState)")
        } else {
            debugPrint("peerConnection RTCIceConnectionState")
        }
        delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        if self.isPrintDebugData {
            debugPrint("peerConnection didGenerate::: \(candidate)")
        } else {
            debugPrint("peerConnection didGenerate")
        }
        delegate?.webRTCClient(self, didGenerate: candidate)
    }
    
    func peerConnection(_: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        if self.isPrintDebugData {
            debugPrint("peerConnection didRemove::: \(candidates)")
        } else {
            debugPrint("peerConnection didRemove")
        }
    }
    
    func peerConnection(_: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        if self.isPrintDebugData {
            debugPrint("peerConnection didOpen::: \(dataChannel)")
        } else {
            debugPrint("peerConnection didOpen")
        }
        remoteDataChannel = dataChannel
        remoteDataChannel?.delegate = self
    }
}
//MARK: - Data ChannelDelegate
extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        if self.isPrintDebugData {
            debugPrint("dataChannel didChangeState readyState::: \(dataChannel.readyState)")
        } else {
            debugPrint("dataChannel didChangeState readyState")
        }
    }
    
    func dataChannel(_: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        delegate?.webRTCClient(self, didReceiveData: buffer.data)
    }
}
