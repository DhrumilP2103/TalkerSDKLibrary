//
//  ChannelConfigurationView.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 11/06/24.
//

import Foundation
import SwiftUI
import WebRTC
import AWSCore
import AWSKinesisVideo
import AWSMobileClient
import AWSKinesisVideoSignaling


class ChannelConfigurationViewModel: ObservableObject {
    
    @Published var signalingConnected: Bool = false
    @Published var remoteSenderClientId: String = ""
    @Published var channelName: String = ""
    @Published var regionName: String = ""
    @Published var clientID: String = ""
    @Published var sendAudioEnabled: Bool = false
    @Published var isMaster: Bool = false
    
    @Published var localSenderId: String = ""
    @Published var signalingClient: SignalingClient?
    @Published var webRTCClient: WebRTCClient?
    @Published var endPoint: String?
    
    @State var isPrintDebugData: Bool = false
    
    var delegate: EventListnerDelegate?
    
    func setRemoteSenderClientId() {
        if self.remoteSenderClientId == "" {
            remoteSenderClientId = connectAsViewClientId
        }
    }
    
    // Pass recipientClientID for sendAnswer in signalingClient
    func sendAnswer(recipientClientID: String) {
        webRTCClient?.answer { localSdp in
            self.signalingClient?.sendAnswer(rtcSdp: localSdp, recipientClientId: recipientClientID)
            print("Sent answer. Update peer connection map and handle pending ice candidates")
            self.webRTCClient?.updatePeerConnectionAndHandleIceCandidates(clientId: recipientClientID)
        }
    }
    
    // Connection Strat
    func connectAsRole(_ channelName: String = "webrtc-talker", _ regionName: String = "", _ isMaster: Bool = false, closure: ((Bool, String)->())?) {
        // Clouser : - navigation, id, ErrorStr
        // Attempt to gather User Inputs
        self.isMaster = isMaster
        self.regionName = regionName
        let channelNameValue = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelNameValue.isEmpty else {
//            print("Channel name is required")
            self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "Channel name is required")
            closure?(false, "Channel name is required")
            // Handle error, maybe using an @Published error property
            return
        }
        
        let awsRegionValue = regionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !awsRegionValue.isEmpty else {
//            print("Region name is required for WebRTC connection")
            self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "Region name is required for WebRTC connection")
            closure?(false, "Region name is required for WebRTC connection")
            // Handle error, maybe using an @Published error property
            return
        }
        
        let awsRegionType = awsRegionValue.aws_regionTypeValue()
        if awsRegionType == .Unknown {
            // Handle error
            return
        }
        
        // If ClientID is not provided generate one
        if self.clientID.isEmpty {
//            self.localSenderId = NSUUID().uuidString.lowercased()
            let user_auth_token = UserDefaults.standard.value(forKey: "user_auth_token") as? String ?? NSUUID().uuidString.lowercased()
            let arrayOftoek = user_auth_token.components(separatedBy: "|")
            var clientid = NSUUID().uuidString.lowercased()
            if arrayOftoek.count > 2{
                clientid = arrayOftoek[2]
            }
            self.localSenderId = clientid
            print("Generated clientID is \(self.localSenderId)")
        } else {
            self.localSenderId = self.clientID
        }
        
        // Kinesis Video Client Configuration
        let configuration = AWSServiceConfiguration(region: awsRegionType, credentialsProvider: AWSMobileClient.default())
        AWSKinesisVideo.register(with: configuration!, forKey: awsKinesisVideoKey)
        
        // Attempt to retrieve signalling channel. If it does not exist, create the channel
        
        let channelARN = retrieveChannelARN(channelName: channelNameValue)
        if channelARN == nil {
//            channelARN = createChannel(channelName: channelNameValue)
            closure?(false, "Channel name is required")
//            if channelARN == nil {
//                print("Please validate all the input fields")
//                closure?(false)
//                // Handle error
//                return
//            }
        }
        
        // Check whether signalling channel will save its recording to a stream (only applies for master)
        let usingMediaServer: Bool = false
        
        // Get signalling channel endpoints
        if channelARN != nil || channelARN == ""{
            let endpoints = getSignallingEndpoints(channelARN: channelARN!, region: awsRegionValue, isMaster: self.isMaster, useMediaServer: usingMediaServer)
            self.endPoint = endPoint
            let wssURL = createSignedWSSUrl(channelARN: channelARN!, region: awsRegionValue, wssEndpoint: endpoints["WSS"]!, isMaster: self.isMaster)
            print(wssURL != nil ? "WSS URL Genrated" : "WSS URL Not Genrated")
            
            //        if self.isPrintDebugData {
            //            print("WSS URL::: ", wssURL?.absoluteString as Any)
            //        }
            // Get ICE candidates using HTTPS endpoint
            let httpsEndpoint = AWSEndpoint(region: awsRegionType, service: .KinesisVideo, url: URL(string: endpoints["HTTPS"]!!))
            let RTCIceServersList = getIceCandidates(channelARN: channelARN!, endpoint: httpsEndpoint!, regionType: awsRegionType, clientId: localSenderId)
            webRTCClient = WebRTCClient(iceServers: RTCIceServersList, isAudioOn: sendAudioEnabled)
            
            // Now Call delegates methods
            webRTCClient!.delegate = self
            print("Connecting to web socket from channel config")
            signalingClient = SignalingClient(serverUrl: wssURL!)
            signalingClient?.delegate = self
            signalingClient?.connect()
            
            closure?(true, "")
        } else {
            closure?(false, "error")
        }
    }
    
    // Get signalling endpoints for the given signalling channel ARN
    func getSignallingEndpoints(channelARN: String, region: String, isMaster: Bool, useMediaServer: Bool) -> Dictionary<String, String?> {
        
        var endpoints = Dictionary <String, String?>()
        /*
         equivalent AWS CLI command:
         aws kinesisvideo get-signaling-channel-endpoint --channel-arn channelARN --single-master-channel-endpoint-configuration Protocols=WSS,HTTPS[,WEBRTC],Role=MASTER|VIEWER --region cognitoIdentityUserPoolRegion
         Note: only include WEBRTC in Protocols if you need a media-server endpoint
         */
        let singleMasterChannelEndpointConfiguration = AWSKinesisVideoSingleMasterChannelEndpointConfiguration()
        singleMasterChannelEndpointConfiguration?.protocols = videoProtocols
        singleMasterChannelEndpointConfiguration?.role = getSingleMasterChannelEndpointRole(isMaster: isMaster)
        
        if(useMediaServer){
            singleMasterChannelEndpointConfiguration?.protocols?.append("WEBRTC")
        }
        
        let kvsClient = AWSKinesisVideo(forKey: awsKinesisVideoKey)
        
        let signalingEndpointInput = AWSKinesisVideoGetSignalingChannelEndpointInput()
        signalingEndpointInput?.channelARN = channelARN
        signalingEndpointInput?.singleMasterChannelEndpointConfiguration = singleMasterChannelEndpointConfiguration
        
        kvsClient.getSignalingChannelEndpoint(signalingEndpointInput!).continueWith(block: { (task) -> Void in
            if let error = task.error {
                if self.isPrintDebugData {
                    print("Error to get channel endpoint::: \(error)")
                    self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "\(error)")
                    
                } else {
                    print("Error to get channel endpoint")
                }
            } else {
                if self.isPrintDebugData {
                    print("Resource Endpoint List::: ", task.result!.resourceEndpointList!)
                } else {
                    print("Resource Endpoint List")
                }
            }
            //TODO: Test this popup
            guard (task.result?.resourceEndpointList) != nil else {
                //                self.popUpError(title: "Invalid Region Field", message: "No endpoints found")
                return
            }
            for endpoint in task.result!.resourceEndpointList! {
                switch endpoint.protocols {
                case .https:
                    endpoints["HTTPS"] = endpoint.resourceEndpoint
                case .wss:
                    endpoints["WSS"] = endpoint.resourceEndpoint
                case .webrtc:
                    endpoints["WEBRTC"] = endpoint.resourceEndpoint
                case .unknown:
                    if self.isPrintDebugData {
                        print("Error: Unknown endpoint protocol::: ", endpoint.protocols, "for endpoint" + endpoint.description())
                    } else {
                        print("Error: Unknown endpoint protocol")
                    }
                @unknown default:
                    fatalError()
                }
            }
        }).waitUntilFinished()
        return endpoints
    }
    
    // create Signed WSS Url
    func createSignedWSSUrl(channelARN: String, region: String, wssEndpoint: String?, isMaster: Bool) -> URL? {
        // get AWS credentials to sign WSS Url with
        var AWSCredentials : AWSCredentials?
        AWSMobileClient.default().getAWSCredentials { credentials, _ in
            AWSCredentials = credentials
        }
        
        while(AWSCredentials == nil){
            usleep(5)
        }
        
        var httpURlString = wssEndpoint!
        + "?X-Amz-ChannelARN=" + channelARN
        if !isMaster {
            httpURlString += "&X-Amz-ClientId=" + self.localSenderId
        }
        let httpRequestURL = URL(string: httpURlString)
        let wssRequestURL = URL(string: wssEndpoint!)
        let wssURL = KVSSigner
            .sign(signRequest: httpRequestURL!,
                  secretKey: (AWSCredentials?.secretKey)!,
                  accessKey: (AWSCredentials?.accessKey)!,
                  sessionToken: (AWSCredentials?.sessionKey)!,
                  wssRequest: wssRequestURL!,
                  region: region)
        return wssURL
    }
    
    // Check if get Single is master or not
    func getSingleMasterChannelEndpointRole(isMaster: Bool) -> AWSKinesisVideoChannelRole {
        if isMaster {
            return .master
        }
        return .viewer
    }
    
    // create Channel ARN if not retrieve Channel ARN
    func createChannel(channelName: String) -> String? {
        var channelARN : String?
        /*
         equivalent AWS CLI command:
         aws kinesisvideo create-signaling-channel --channel-name channelName --region cognitoIdentityUserPoolRegion
         */
        let kvsClient = AWSKinesisVideo(forKey: awsKinesisVideoKey)
        let createSigalingChannelInput = AWSKinesisVideoCreateSignalingChannelInput.init()
        createSigalingChannelInput?.channelName = channelName
        kvsClient.createSignalingChannel(createSigalingChannelInput!).continueWith(block: { (task) -> Void in
            if let error = task.error {
//                print("Error creating channel")
                self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "\(error)")
            } else {
                if self.isPrintDebugData {
                    print("Channel ARN::: ", task.result?.channelARN ?? "")
                } else {
                    print("Channel ARN")
                }
                channelARN = task.result?.channelARN
            }
        }).waitUntilFinished()
        return channelARN
    }
    
    // retrieve Channel ARN
    func retrieveChannelARN(channelName: String) -> String? {
        var channelARN : String?
        /*
         equivalent AWS CLI command:
         aws kinesisvideo describe-signaling-channel --channelName channelName --region cognitoIdentityUserPoolRegion
         */
        let describeInput = AWSKinesisVideoDescribeSignalingChannelInput()
        describeInput?.channelName = channelName
        let kvsClient = AWSKinesisVideo(forKey: awsKinesisVideoKey)
        kvsClient.describeSignalingChannel(describeInput!).continueWith(block: { (task) -> Void in
            if let error = task.error {
//                print("Error describing channel")
                self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "\(error)")
            } else {
                if self.isPrintDebugData {
                    print("Retrive Channel ARN::: ", task.result!.channelInfo!.channelARN ?? "Channel ARN empty.")
                } else {
                    print("Retrive Channel ARN")
                }
                channelARN = task.result?.channelInfo?.channelARN
            }
        }).waitUntilFinished()
        return channelARN
    }
    
    // Get Ice Candidates
    func getIceCandidates(channelARN: String, endpoint: AWSEndpoint, regionType: AWSRegionType, clientId: String) -> [RTCIceServer] {
        var RTCIceServersList = [RTCIceServer]()
        // TODO: don't use the self.regionName.text!
        let kvsStunUrlStrings = ["stun:stun.kinesisvideo." + self.regionName + ".amazonaws.com:443"]
        /*
         equivalent AWS CLI command:
         aws kinesis-video-signaling get-ice-server-config --channel-arn channelARN --client-id clientId --region cognitoIdentityUserPoolRegion
         */
        let configuration =
        AWSServiceConfiguration(region: regionType,
                                endpoint: endpoint,
                                credentialsProvider: AWSMobileClient.default())
        AWSKinesisVideoSignaling.register(with: configuration!, forKey: awsKinesisVideoKey)
        let kvsSignalingClient = AWSKinesisVideoSignaling(forKey: awsKinesisVideoKey)
        
        let iceServerConfigRequest = AWSKinesisVideoSignalingGetIceServerConfigRequest.init()
        
        iceServerConfigRequest?.channelARN = channelARN
        iceServerConfigRequest?.clientId = clientId
        kvsSignalingClient.getIceServerConfig(iceServerConfigRequest!).continueWith(block: { (task) -> Void in
            if let error = task.error {
                self.delegate?.onServerConnectionChange(serverConnectionState: .Failure, message: "\(error)")
            } else {
                if self.isPrintDebugData {
                    print("ICE Server List::: ", task.result!.iceServerList!)
                } else {
                    print("ICE Server List")
                }
                for iceServers in task.result!.iceServerList! {
                    RTCIceServersList.append(RTCIceServer.init(urlStrings: iceServers.uris!, username: iceServers.username, credential: iceServers.password))
                }
                
                RTCIceServersList.append(RTCIceServer.init(urlStrings: kvsStunUrlStrings))
            }
        }).waitUntilFinished()
        return RTCIceServersList
    }
}

//MARK: -  Delegate Methods for SignalClient and WebRTCClient
extension ChannelConfigurationViewModel: SignalClientDelegate, WebRTCClientDelegate  {
    func webRTCClient(_: WebRTCClient, didGenerate candidate: RTCIceCandidate) {
        print("Generated local candidate")
        setRemoteSenderClientId()
        signalingClient?.sendIceCandidate(rtcIceCandidate: candidate, master: isMaster,
                                          recipientClientId: remoteSenderClientId,
                                          senderClientId: localSenderId)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        
        switch state {
        case .connected, .completed:
            print("WebRTC connected/completed state")
            UserDefaults.standard.setValue("1", forKey: "WebrtcIsConnected")
            self.delegate?.onServerConnectionChange(serverConnectionState: .Success, message: "WebRTC connected/completed state")
        case .disconnected:
            print("WebRTC disconnected state")
            UserDefaults.standard.setValue("0", forKey: "WebrtcIsConnected")
        case .new:
            print("WebRTC new state")
        case .checking:
            print("WebRTC checking state")
        case .failed:
            print("WebRTC failed state")
        case .closed:
            print("WebRTC closed state")
            self.delegate?.onServerConnectionChange(serverConnectionState: .Closed, message: "WebRTC closed state")
            UserDefaults.standard.setValue("0", forKey: "WebrtcIsConnected")
        case .count:
            print("WebRTC count state")
        @unknown default:
            print("WebRTC unknown state")
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print("Received local data", String(data: data, encoding: .utf8) ?? "")
    }
    
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        print("signalClientDidConnect")
        signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        print("signalClientDidDisconnect")
        signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalingClient, senderClientId: String, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("didReceiveRemoteSdp")
        if !senderClientId.isEmpty {
            remoteSenderClientId = senderClientId
        }
        setRemoteSenderClientId()
        webRTCClient!.set(remoteSdp: sdp, clientId: senderClientId) { _ in
            print("Setting remote sdp and sending answer.")
            self.sendAnswer(recipientClientID: self.remoteSenderClientId)
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, senderClientId: String, didReceiveCandidate candidate: RTCIceCandidate) {
        print("didReceiveCandidate")
        if !senderClientId.isEmpty {
            remoteSenderClientId = senderClientId
        }
        setRemoteSenderClientId()
        webRTCClient!.set(remoteCandidate: candidate, clientId: senderClientId)
    }
    
}
