//
//  Talker.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 01/08/24.
//

import Foundation
import AWSCore
import AWSAuthCore
import AWSCognitoIdentityProvider
import AWSMobileClientXCF
import SocketIO
import AVFoundation

class AppData {
    static var shared = AppData()
    
    var channelConfigurationModel = ChannelConfigurationViewModel()
    var userListData = [UserListData]()
    var channelListData = [ChannelListData]()
    var messageListData = [MessageListData]()
    
    private init() {} // Prevents others from creating instances
}

public class Talker {
    private var socket: SocketIOClient!
    private var manager: SocketManager!
    private var audioPlayer: AVPlayer = AVPlayer()
    private var urlAudio: String = ""
    private var audioRecorder: AudioRecorder? 
    private var webRTCClient: WebRTCClient?
    private var signalingClient: SignalingClient?
    
    public var isFirstTimeLogin = false
    var errorCount = 0
    var delegate: EventListnerDelegate?
    var talker_database = Talker_Database()
    /// Registers a new user with the specified name.
    /// Calls the completion handler with the registration status and any error encountered.
    public func register(name: String, completionHandler: @escaping ((Bool, String) -> Void)) {
        let isFirstTime = UserDefaults.standard.value(forKey: "isFirstTime")
        
        if (isFirstTime != nil) != true {
            UserDefaults.standard.setValue(true, forKey: "isFirstTime")
            self.isFirstTimeLogin = true
        } else {
            self.isFirstTimeLogin = false
        }
        
        self.create_user(name: name) { status in
            if status {
                self.awsLogin() { status, error in
                    if status {
                        print("The user is signedIn")
                        AppData.shared.userListData = self.talker_database.getUsersList()
                        AppData.shared.channelListData = self.talker_database.getChannelsList()
                        completionHandler(status, error)
                    } else {
                        completionHandler(false, error)
                    }
                }
            } else {
                completionHandler(status, "registraion error")
            }
        }
    }
    
    /// Login the user with the specified userId.
    /// Calls the completion handler with the login status and any error encountered.
    public func login(userId: String, completionHandler: @escaping ((Bool, String) -> Void)) {
        self.set_current_user (userID: userId) { status in
            if status {
                self.awsLogin() { status, error in
                    if status {
                        AppData.shared.userListData = self.talker_database.getUsersList()
                        AppData.shared.channelListData = self.talker_database.getChannelsList()
                        completionHandler(status, error)
                    } else {
                        completionHandler(status, error)
                    }
                }
            } else {
                completionHandler(status, "Login Error")
            }
        }
    }
    
    /// Logout the current user from AWS Login.
    public func logOut() {
        AWSMobileClient.default().signOut()
        print("Logout Successs")
    }
    
    /// Establishes a connection for WebRTC and signaling, setting up audio recording and WebRTC offer.
    /// Calls the completion handler with the connection status.
    public func establishConnection(completionHandler: @escaping ((Bool, String) -> Void)) {
        let channelName = "\(UserDefaults.standard.value(forKey: "channelName") ?? "")"
        let regionName = "\(UserDefaults.standard.value(forKey: "regionName") ?? "")"
        AppData.shared.channelConfigurationModel.delegate = delegate
        AppData.shared.channelConfigurationModel.connectAsRole(channelName, regionName) { status, error in
            if status {
                self.initConnection()
                completionHandler(status, error)
            } else {
                if self.errorCount < 2 {
                    self.errorCount += 1
                    self.establishConnection(completionHandler: completionHandler)
                } else {
                    completionHandler(false, error)
                }
            }
        }
    }
    
    public func getChannelMessages(channelId: String) -> [MessageListData] {
        return self.talker_database.getChannelMessages(channelIdValue: channelId)
    }

    public func initConnection() {
        self.webRTCClient = AppData.shared.channelConfigurationModel.webRTCClient
        self.signalingClient = AppData.shared.channelConfigurationModel.signalingClient
        let localSenderClientID = AppData.shared.channelConfigurationModel.localSenderId

        let dataChannel = self.webRTCClient?.createDataChannelForAudio()
        self.audioRecorder = AudioRecorder(dataChannel: dataChannel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 , execute: {
            self.webRTCClient?.offer { sdp in
                self.signalingClient?.sendOffer(rtcSdp: sdp, senderClientid: localSenderClientID)
            }
            self.connectSocket()
            self.webRTCClient?.localAudioTrack?.isEnabled = false
            
        })
    }
    
    /// Closes the WebRTC and signaling connections, and disconnects the socket.
    public func closeConnection() {
        self.webRTCClient?.shutdown()
        self.signalingClient?.disconnect()
        self.socket.disconnect()
    }
    
    /// Starts push-to-talk audio by emitting a broadcast start event and starting audio recording.
    /// Calls the completion handler with the Cahnnel Avilable status.
    public func startPttAudio(selectedChannelId: String = "",completionHandler: @escaping ((Bool) -> Void))  {
        if !checkInternet() {
            self.closeConnection()
            completionHandler(false)
            return
        }
        var channelId = ""
        if selectedChannelId == "" {
            channelId = "\(UserDefaults.standard.value(forKey: "channelId") ?? "")"
        } else {
            channelId = selectedChannelId
        }
        let data: [String: Any] = ["channel_id": channelId]
        
        let isConnected = "\(UserDefaults.standard.value(forKey: "WebrtcIsConnected") ?? 0)"
        
        if isConnected == "0" {
            completionHandler(false)
            self.closeConnection()
            self.showLoader()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                self.establishConnection { status, _ in
                    if status {
                        self.dismissLoader()
                    }
                }
            })
        }
        
        self.socket.emitWithAck("broadcast_start", data).timingOut(after: 1) { data in
            if data.first as? Bool ?? false {
                self.sendAudioStartData(channelId: channelId)
                self.audioRecorder?.isRecordingStart = true
                self.audioRecorder?.startRecording()
                self.delegate?.onAudioStatusChange(audioStatus: .Connecting)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 , execute: {
                    self.delegate?.onAudioStatusChange(audioStatus: .Sending)
                })
                completionHandler(true)
            } else {
                self.delegate?.onAudioStatusChange(audioStatus: .Connecting)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 , execute: {
                    self.delegate?.onAudioStatusChange(audioStatus: .Busy)
                })
                completionHandler(false)
            }
        }
    }
    
    /// Stops push-to-talk audio by emitting a broadcast end event and stopping audio recording.
    public func stopPttAudio(selectedChannelId: String = "") {
        if !checkInternet() {
            self.closeConnection()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            var channelId = ""
            if selectedChannelId == "" {
                channelId = "\(UserDefaults.standard.value(forKey: "channelId") ?? "")"
            } else {
                channelId = selectedChannelId
            }
            self.sendAudioStoptData(channelId: channelId)
            let data: [String: Any] = ["channel_id": channelId]
            self.socket.emit("broadcast_end", data)
            self.delegate?.onAudioStatusChange(audioStatus: .Stopped)
            if self.audioRecorder?.isRecordingStart == true {
                self.audioRecorder?.isRecordingStart = false
                self.audioRecorder?.stopRecording()
            }
        })
    }
    
    /// Checks if the channel is available by sending a "broadcast_start" event to the socket.
    /// - Parameter completion: A closure that is called with a boolean indicating if the channel is available.
    public func channelAvailable(completion: @escaping (Bool) -> Void) {
        
        let channelId = "\(UserDefaults.standard.value(forKey: "channelId") ?? "")"
        let data: [String: Any] = ["channel_id": channelId]
        
        self.socket.emitWithAck("broadcast_start", data).timingOut(after: 1) { data in
            if data.first as? Bool ?? false {
                completion(true)
            } else {
                completion(false)
            }
        }
        
        self.socket.emit("broadcast_end", data)
    }

    /// Retrieves the current user ID.
    /// Removes stored the user ID  when the app is deleted.
    /// - Returns: A string representing the current user ID.
    public func getCurrentUserId() -> String{
        return "\(UserDefaults.standard.value(forKey: "userId") ?? "")"
    }
    
    public func getCurrentUser() -> (String, String){
        return ("\(UserDefaults.standard.value(forKey: "userId") ?? "")", "\(UserDefaults.standard.value(forKey: "name") ?? "")")
    }
    
    public func showLoader() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            KRProgressHUD.set(activityIndicatorViewColors: [UIColor.green ])
            KRProgressHUD.show()
        })
    }
    
    public func dismissLoader() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
            KRProgressHUD.dismiss()
        })
    }
}

// Only Private Functions
extension Talker {
    /// Connects to the socket with the specified configuration and sets up event listeners for broadcast start and end.
    private func connectSocket() {
        let config: SocketIOClientConfiguration = [
            .log(false),
            .compress,
            .forcePolling(false),
            .forceWebsockets(true),
            .extraHeaders(["Authorization": "\(UserDefaults.standard.value(forKey: "user_auth_token") ?? "")" ])
        ]

        self.manager = SocketManager(socketURL: URL(string: "https://test-api.talker.network")!, config: config)
//        self.socket = manager.defaultSocket
        self.socket = self.manager.socket(forNamespace: "/sockets")
        self.socket.connect()
        self.socket.manager?.reconnects = true
        self.socket.on("broadcast_start"){ data, ack  in
            ack.with()
            print("broadcast_start data::: ",data)
            if data.count > 0{
                let datString = data[0] as? String
                let dataObj = datString?.decodeJSONString()
                let media_link : String = dataObj?["media_link"] as? String ?? ""
                let channel_id : String = dataObj?["channel_id"] as? String ?? ""
                let sender_id : String = dataObj?["sender_id"] as? String ?? ""
                let channel_name : String = dataObj?["channel_name"] as? String ?? ""
                let sender_name : String = dataObj?["channel_name"] as? String ?? ""
                let userId = "\(UserDefaults.standard.value(forKey: "userId") ?? "")"
                
                if sender_id != userId{
                    if media_link != userId{
                        self.urlAudio = media_link
                        self.playSound(url: media_link)
                        
                        let channel = self.talker_database.getChannelsList()
                        let channelData = channel.filter { $0.channelId == channel_id }
                        var channelName = ""
                        if channelData.count > 0 {
                            channelName = channel_name == "" ? channelData[0].groupName ?? "" : channel_name
                        }
                        
                        let userlist = self.talker_database.getUsersList()
                        let userData = userlist.filter { $0.userId == sender_id }
                        var senderName = ""
                        if userData.count > 0 {
                            senderName = sender_name == "" ? userData[0].name ?? "" : sender_name
                        }
                        
                        self.delegate?.currentPttAudio(sender_id: sender_id, channel_id: channel_id, channel_name: channelName, sender_name: senderName)
                    }
                }
            }
        }
        
        self.socket.on("broadcast_end"){ data, ack in
            ack.with()
            print("broadcast_end",data)
        }
        
        self.socket.on("new_channel") { data, ack in
            ack.with()
            print("new_channel:::" , data)
            self.delegate?.onNewChannelCreate(data: data)
        }
        
        self.socket.on("room_name_update") { data, ack in
            ack.with()
            print("room_name_update::: ",data)
            self.delegate?.onChannelUpdated(data: data)
        }
        
        self.socket.on("room_participant_added") { data, ack in
            ack.with()
            print("room_participant_added::: ", data)
            self.delegate?.onAddedUserInChannel(data: data)
        }
        
        self.socket.on("room_participant_removed") { data, ack in
            ack.with()
            print("room_participant_removed::: ", data)
            self.delegate?.onRemovedUserFromChannel(data: data)
        }
        
        self.socket.on("room_admin_added") { data, ack in
            ack.with()
            print("room_admin_added::", data)
            self.delegate?.onAdminAdded(data: data)
        }
        
        self.socket.on("room_admin_removed") { data, ack in
            ack.with()
            print("room_admin_removed::", data)
            self.delegate?.onAdminRemoved(data: data)
        }
        
        self.socket.on("new_sdk_user") { data, ack in
            ack.with()
            print("new_sdk_user:::", data)
        }
        
        self.socket.on("message") { data, ack in
//            ack.with()
            print("message:::", data)
            self.delegate?.onNewMessageReceived(data: data)
        }
        
        self.socket.on(clientEvent: .error) { data, ack in
            if self.errorCount < 2 {
                self.errorCount += 1
                self.connectSocket()
            }
        }
        
        self.socket.on(clientEvent: .connect) { data, ack in
            print("Socket connected")
        }
        
        self.socket.on(clientEvent: .disconnect) { data, ack in
            print("Socket disconnect")
        }
    }
    
    /// Plays sound from the specified URL.
    private func playSound(url: String) {
        do {
            self.setSessionPlayAndRecord()
            self.audioPlayer.replaceCurrentItem(with: AVPlayerItem(url: URL(string: url)!))
            self.audioPlayer.play()
        }
    }
    
    /// Sets the AVAudioSession category to play and record, activates the session, and overrides the output audio port to speaker.
    private func setSessionPlayAndRecord() {
        do {
            let session:AVAudioSession = AVAudioSession.sharedInstance()
            try session.setCategory(AVAudioSession.Category.playAndRecord)
            try session.setActive(true)
            try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        } catch {
            print("Error converting dictionary to JSON string: \(error)")
        }
    }
    
    /// Sends a message to the server indicating the start of an audio stream.
    private func sendAudioStartData(channelId: String){
        let uuid = UUID().uuidString
        let message: [String: Any] = [
            "type": "stream_start",
            "channel_id": channelId,
            "message_id": "\(uuid)",
            "bit_depth": "8",
            "sample_rate": "16000",
            "receiver_count": "2"
        ]
        
        if let jsonString = jsonToString(json: message) {
            self.webRTCClient?.sendMessge(message: jsonString)
        }
    }
    
    /// Sends a message to the server indicating the end of an audio stream.
    private func sendAudioStoptData(channelId: String) {
        let message: [String: Any] = [
            "type": "stream_end",
            "channel_id": channelId
        ]
        
        if let jsonString = jsonToString(json: message) {
            self.webRTCClient?.sendMessge(message: jsonString)
        }
    }
    
    /// Converts a JSON dictionary to a JSON string. Returns the string if successful, or nil if an error occurs.
    private func jsonToString(json: [String: Any]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            print("Error converting dictionary to JSON string: \(error)")
            return nil
        }
    }
    
    /// Login to AWS using the stored credentials and calls the completion handler with the login status and any error encountered.
    private func awsLogin(completionHandler: @escaping ((Bool, String) -> Void)) {
        let serviceConfiguration = AWSServiceConfiguration(region: cognitoIdentityUserPoolRegion,
                                                           credentialsProvider: nil)
        
        // create pool configuration
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: cognitoIdentityUserPoolAppClientId,
                                                                        clientSecret: cognitoIdentityUserPoolAppClientSecret,
                                                                        poolId: cognitoIdentityUserPoolId)
        
        // Register the user pool
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: poolConfiguration, forKey: awsCognitoUserPoolsSignInProviderKey)
        
        // Create dynamic configuration
        let dynamicConfig: [String: Any] = [
            "Version": "1.0",
            "CredentialsProvider": [
                "CognitoIdentity": [
                    "Default": [
                        "PoolId": "\(cognitoIdentityPoolId)",
                        "Region": "\(credentialsRegion)"
                    ]
                ]
            ],
            "IdentityManager": [
                "Default": [:]
            ],
            "CognitoUserPool": [
                "Default": [
                    "AppClientSecret": "\(cognitoIdentityUserPoolAppClientSecret)",
                    "AppClientId": "\(cognitoIdentityUserPoolAppClientId)",
                    "PoolId": "\(cognitoIdentityUserPoolId)",
                    "Region": "\(cognitoUserRegion)"
                ]
            ]
        ]
        // Apply the dynamic configuration to AWS
        AWSInfo.configureDefaultAWSInfo(dynamicConfig)
        
        var isSignedIn = false
        AWSMobileClient.default().initialize { (userState, error) in
            if let error = error {
                print("error: \(error.localizedDescription)")
                completionHandler(false, error.localizedDescription)
                return
            }
            
            guard let userState = userState else {
                completionHandler(false, "Unknown user state")
                return
            }
            
            switch userState {
            case .signedIn:
                isSignedIn = true
                completionHandler(true, "")
            case .signedOut:
                isSignedIn = false
            default:
                print("Default state")
            }
        }
        
        if !isSignedIn {
            let username = "\(UserDefaults.standard.value(forKey: "aUsername") ?? "")"
            let password = "\(UserDefaults.standard.value(forKey: "aPass") ?? "")"
            AWSMobileClient.default().signIn(username: username, password: password) { (signInResult, error) in
                if let error = error {
                    completionHandler(false, "\(error)")
                } else if let signInResult = signInResult {
                    print(signInResult)
                    print("The user is signedIn")
                    completionHandler(true, "")
                }
            }
        }
    }

}

// API Call
extension Talker {
    
    /// Creates a new user on the server.
    /// - Parameters:
    ///   - name: The name of the user.
    ///   - completionHandler: Completion handler that returns a boolean indicating success or failure.
    private func create_user(name: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        let fcm = "\(UserDefaults.standard.value(forKey: "fcmToken") ?? "")"
        let ptt_token = "\(UserDefaults.standard.value(forKey: "ptt_token") ?? "")"
        
        // Fetch user list when the view appears
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["name"] = name as AnyObject
        parameter["fcm_token"] = fcm as AnyObject
        parameter["apns_ptt_token"] = ptt_token as AnyObject
        parameter["platform"] = "IOS" as AnyObject
        
        APIService().SdkCreateUserAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.data?.aUsername != "" {
                        UserDefaults.standard.setValue(data.data?.aUsername ?? "", forKey: "aUsername")
                        UserDefaults.standard.setValue(data.data?.aPass ?? "", forKey: "aPass")
                        UserDefaults.standard.setValue(data.data?.userId ?? "", forKey: "userId")
                        UserDefaults.standard.setValue(data.data?.userAuthToken ?? "", forKey: "user_auth_token")
                        UserDefaults.standard.setValue(data.data?.name ?? "", forKey: "name")
                        self.sdkCred() { status in
                            if status {
                                self.get_channel_list() {status in }
                                self.get_all_user() { status in }
                                completionHandler(true)
                            }
                        }
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        } onError: { data, statusCode, success in
            print("----\(data.message ?? "")")
        }
    }
    
    /// Sets the current user on the server.
    /// - Parameters:
    ///   - userID: The exsting user ID.
    ///   - completionHandler: Completion handler that returns a boolean indicating success or failure.
    private func set_current_user(userID: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        let fcm = "\(UserDefaults.standard.value(forKey: "fcmToken") ?? "")"
        let ptt_token = "\(UserDefaults.standard.value(forKey: "ptt_token") ?? "")"
        
        // Fetch user list when the view appears
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["prev_user_id"] = userID as AnyObject
        parameter["user_id"] = userID as AnyObject
        parameter["fcm_token"] = fcm as AnyObject
        parameter["apns_ptt_token"] = ptt_token as AnyObject
        parameter["platform"] = "IOS" as AnyObject
        
        APIService().SdkSetUserAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.data?.aUsername != "" {
                        self.sdkCred() { status in
                            if status {
                                if data.data?.userId != self.getCurrentUserId() {
                                    UserDefaults.standard.setValue(data.data?.aUsername ?? "", forKey: "aUsername")
                                    UserDefaults.standard.setValue(data.data?.aPass ?? "", forKey: "aPass")
                                    UserDefaults.standard.setValue(data.data?.userId ?? "", forKey: "userId")
                                    UserDefaults.standard.setValue(data.data?.userAuthToken ?? "", forKey: "user_auth_token")
                                    UserDefaults.standard.setValue(data.data?.name ?? "", forKey: "name")
                                    self.talker_database.deleteAllUsers()
                                    self.talker_database.deleteAllChannels()
                                    
                                    let data = self.talker_database.getChannelsList()
                                    print("data:::", data.count)
                                    self.get_channel_list() { status in
                                        if status {
                                            self.get_all_user() { status in
                                                if status {
                                                    completionHandler(true)
                                                }
                                            }
                                        }
                                    }
                                    
                                } else {
                                    UserDefaults.standard.setValue(data.data?.aUsername ?? "", forKey: "aUsername")
                                    UserDefaults.standard.setValue(data.data?.aPass ?? "", forKey: "aPass")
                                    UserDefaults.standard.setValue(data.data?.userId ?? "", forKey: "userId")
                                    UserDefaults.standard.setValue(data.data?.userAuthToken ?? "", forKey: "user_auth_token")
                                    UserDefaults.standard.setValue(data.data?.name ?? "", forKey: "name")
                                }
                                completionHandler(true)
                            }
                        }
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                } else if statusCode == 403 {
                    completionHandler(false)
                }
            }
        } onError: { data, statusCode, success in
            print("----\(data.message ?? "")")
            completionHandler(false)
        }
    }
    
    /// Fetches SDK credentials from the server.
    /// - Parameter completionHandler: Completion handler that returns a boolean indicating success or failure.
    private func sdkCred(completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        let parameter : [String : AnyObject] = [String : AnyObject]()
        
        APIService().SdkCredAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.data?.generalChannel?.channelId != "" {
                        UserDefaults.standard.setValue(data.data?.cognito?.CredentialsProvider?.CognitoIdentity?.Default?.Region ?? "", forKey: "regionName")
                        UserDefaults.standard.setValue(data.data?.generalChannel?.channelId, forKey: "channelId")
                        UserDefaults.standard.setValue(data.data?.webrtcChannelName ?? "", forKey: "channelName")
                        
                        var cognitoData = data.data?.cognito
                        
                        credentialsRegion = cognitoData?.CredentialsProvider?.CognitoIdentity?.Default?.Region ?? ""
                        
                        cognitoIdentityPoolId = cognitoData?.CredentialsProvider?.CognitoIdentity?.Default?.PoolId ?? ""
                        
                        cognitoIdentityUserPoolAppClientSecret = cognitoData?.CognitoUserPool?.Default?.AppClientSecret ?? ""
                        
                        cognitoIdentityUserPoolAppClientId = cognitoData?.CognitoUserPool?.Default?.AppClientId ?? ""
                        
                        cognitoIdentityUserPoolId = cognitoData?.CognitoUserPool?.Default?.PoolId ?? ""
                        
                        cognitoUserRegion = cognitoData?.CognitoUserPool?.Default?.Region ?? ""
                        completionHandler(true)
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        } onError: { data, statusCode, success in
            print("----\(data.message ?? "")")
        }
    }
    
    /// Fetches SDK channels list from the server.
   private func get_channel_list(completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        let parameter : [String : AnyObject] = [String : AnyObject]()
        
        APIService().GetChannelListAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.data?.channels?.count ?? 0 > 0 {
//                        if self.isFirstTimeLogin {
                            let channelData = data.data?.channels ?? [GetChannels]()
                            for data in channelData {
                                do {
                                    // Serialize participants to JSON string
                                    let participantsData = try JSONEncoder().encode(data.participants)
                                    let participantsString = String(data: participantsData, encoding: .utf8)
                                    self.talker_database.addChannel(
                                        channelTypeValue: data.channelType ?? "",
                                        channelIdValue: data.channelId ?? "",
                                        participantsValue: participantsString ?? "",
                                        groupNameValue: data.groupName ?? "",
                                        pttModeValue: ""
                                    )
                                } catch {
                                    print("Failed to encode participants:", error.localizedDescription)
                                }
                            }
                        completionHandler(true)
                        let data = self.talker_database.getChannelsList()
                        AppData.shared.userListData = self.talker_database.getUsersList()
                        AppData.shared.channelListData = self.talker_database.getChannelsList()
//                        }
                    }

                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        }
    }
    
    /// Fetches SDK users list from the server.
   private func get_all_user(completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        let parameter : [String : AnyObject] = [String : AnyObject]()
        
        APIService().GetAllUserAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.data?.count ?? 0 > 0 {
//                        if self.isFirstTimeLogin {
                            let userData = data.data ?? [ListOfUsersData]()
                            for data in userData {
                                self.talker_database.addUser(nameValue: data.name ?? "", userIdValue: data.userId ?? "")
                            }
                        completionHandler(true)
//                        }
                        AppData.shared.userListData = self.talker_database.getUsersList()
                        AppData.shared.channelListData = self.talker_database.getChannelsList()
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        }
    }
    
    public func create_direct_channel(_ participants: String = "", _ name: String = "" , _ isGroup: Bool = false, completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["participants"] = participants as AnyObject
        parameter["type"] = (isGroup ? "group" : "direct") as AnyObject
        if isGroup {
            parameter["name"] = name as AnyObject
        }
        
        APIService().CreateDirectChannelAPI(parameter: parameter) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if success {
                        completionHandler(true)
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        }
    }
    
    func Update_channel_name(channel_id: String = "" ,new_name: String = "",completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["channel_id"] = channel_id as AnyObject
        parameter["new_name"] = new_name as AnyObject
        
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().EditChannelDataAPI(parameter: parameter) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    func add_channel_participant(channel_id: String = "" , new_participants: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["channel_id"] = channel_id as AnyObject
        parameter["new_participants"] = new_participants as AnyObject
        
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().EditChannelDataAPI(parameter: parameter) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    func remove_channel_participant(channel_id: String = "" , delete_participant: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["channel_id"] = channel_id as AnyObject
        parameter["delete_participant"] = delete_participant as AnyObject
        
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().EditChannelDataAPI(parameter: parameter) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    func add_new_admin(channel_id: String = "" , new_admin: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["channel_id"] = channel_id as AnyObject
        parameter["new_admin"] = new_admin as AnyObject
        
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().EditChannelDataAPI(parameter: parameter) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    func admin_removed(channel_id: String = "" , admin_removed: String = "", completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["channel_id"] = channel_id as AnyObject
        parameter["admin_removed"] = admin_removed as AnyObject
        
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().EditChannelDataAPI(parameter: parameter) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    public func leaveChannel(channel_id: String, completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
//        var parameter : [String : AnyObject] = [String : AnyObject]()
//        parameter["channel_id"] = channel_id as AnyObject
        let data = AppData.shared.channelListData.filter { $0.channelType == "group" }
        let genralData = AppData.shared.channelListData.filter { $0.channelType == "workspace_general" }
        
        if data.contains(where: { $0.channelId == channel_id }) && !genralData.contains(where: { $0.channelId == channel_id }) {
            APIService().leaveChannelAPI(channel_id: channel_id) { data, statusCode, success in
                DispatchQueue.main.async {
                    if statusCode == 200 {
                        if data.success ?? false {
                            completionHandler(true)
                        }
                    } else if statusCode == 500 {
                        completionHandler(false)
                    } else if statusCode == 101 {
                        completionHandler(false)
                    }
                }
            }
        } else {
            completionHandler(false)
        }
    }
    
    public func sendTextMsg(channel_id: String, message: String, completionHandler: @escaping ((Bool) -> Void)) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["description"] = message as AnyObject
        
        APIService().uploadTextAPI(parameter: parameter, channelId: channel_id) { data, statusCode, success in
            DispatchQueue.main.async {
                if statusCode == 200 {
                    if data.success ?? false {
                        completionHandler(true)
                    }
                } else if statusCode == 500 {
                    completionHandler(false)
                } else if statusCode == 101 {
                    completionHandler(false)
                }
            }
        } onError: { data, statusCode, status in
            
        }
    }
    
    public func uploadImage(caption: String,image: UIImage, channel_id: String) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        // Fetch user list when the view appears
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["image"] = image as AnyObject
        parameter["description"] = caption as AnyObject
        
        APIService().makePostHeaderImageCall(url: "\(baseUrl + chat_upload_channel_id_url + channel_id)", parameters: parameter) { data, status in
            
            do {
                
                let jsonData = Data((data as? String ?? "").utf8)
                let decoder = JSONDecoder()
                
                let data : UploadMessageModel = try decoder.decode(UploadMessageModel.self, from: jsonData)
                
                print(data)
                
            } catch {
                print(error.localizedDescription)
            }
        }
        
    }
    
    public func uploadDocument(document: Data, channel_id: String) {
        if !checkInternet() {
            print("No Internet Available")
            return
        }
        
        // Fetch user list when the view appears
        var parameter : [String : AnyObject] = [String : AnyObject]()
        parameter["document"] = document as AnyObject
        
        APIService().makePostHeaderImageCall(url: "\(baseUrl + chat_upload_channel_id_url + channel_id)", parameters: parameter) { data, status in
            
            do {
                
                let jsonData = Data((data as? String ?? "").utf8)
                let decoder = JSONDecoder()
                
                let data : UploadMessageModel = try decoder.decode(UploadMessageModel.self, from: jsonData)
                
                print(data)
                
            } catch {
                print(error.localizedDescription)
            }
        }
        
    }
}


