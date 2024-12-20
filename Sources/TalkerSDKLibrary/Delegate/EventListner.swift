//
//  EventListner.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 10/07/24.
//

import Foundation

public enum AudioStatus : String {
    case Connecting = "Connecting"
    case Busy = "Busy"
    case Sending = "Sending"
    case Stopped = "Stopped"
    
}

public enum ServerConnectionState: String {
    case Success = "Success"
    case Failure = "Failure"
    case Closed = "Closed"
}

/// A protocol for listening to various events in the application.
public protocol EventListnerDelegate {
    func onAudioStatusChange(audioStatus: AudioStatus)
    func onServerConnectionChange(serverConnectionState: ServerConnectionState, message: String)
    func onNewChannelCreate(data: [Any])
    func onChannelUpdated(data: [Any])
    func onRemovedUserFromChannel(data: [Any])
    func onAddedUserInChannel(data: [Any])
    func onAdminAdded(data: [Any])
    func onAdminRemoved(data: [Any])
    func onNewMessageReceived(data: [Any])
    func currentPttAudio(sender_id: String, channel_id: String, channel_name: String, sender_name: String)
}

public class EventListner: ObservableObject, EventListnerDelegate {
    
    @Published public var onAudioStatus: ((AudioStatus) -> ())?
    @Published public var onServerConnection: ((ServerConnectionState) -> ())?
    @Published public var onNewChannel: ((_ channelId: String, _ channelType: String, _ participants: [GetParticipants], _ groupName: String) -> ())?
    @Published public var onChannelUpdated: ((_ new_name: String) -> ())?
    @Published public var onRemovedUserFromChannel: ((String) -> ())?
    @Published public var onAddedUserInChannel: (([[String: Any]]) -> ())?
    @Published public var onAdminAdded: ((String) -> ())?
    @Published public var onAdminRemoved: ((String) -> ())?
    @Published public var currentPttAudio: ((_ sender_id: String, _ channel_id: String, _ channel_name: String, _ sender_name: String) -> ())?
    
    public var talker_database = Talker_Database()
    
    public init() {}
    
    public func currentPttAudio(sender_id: String, channel_id: String, channel_name: String, sender_name: String) {
        self.currentPttAudio?(sender_id, channel_id, channel_name, sender_name)
    }
    
    public func onAudioStatusChange(audioStatus: AudioStatus) {
        self.onAudioStatus?(audioStatus)
    }
    
    public func onServerConnectionChange(serverConnectionState: ServerConnectionState, message: String) {
        self.onServerConnection?(serverConnectionState)
    }
    
    public func onNewChannelCreate(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id: String = dataObj?["channel_id"] as? String ?? ""
            let channel_type: String = dataObj?["channel_type"] as? String ?? ""
            let participants = dataObj?["participants"] as? [[String: Any]] ?? []
            let group_name: String = dataObj?["group_name"] as? String ?? ""
            let storedChannelId = AppData.shared.channelListData.filter { $0.channelId == channel_id }
            
            if storedChannelId.count == 0 {
                var userId = ""
                let participantObjects = participants.map { participant -> GetParticipants in
                    userId = participant["user_id"] as? String ?? ""
                    let name = participant["name"] as? String ?? ""
                    let admin = participant["admin"] as? Bool ?? false
                    return GetParticipants(userId: userId, name: name, admin: admin)
                }
                
                // Convert participants to JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: participants, options: .prettyPrinted) {
                    let jsonString = String(data: jsonData, encoding: .utf8)
                    self.talker_database.addChannel(channelTypeValue: channel_type, channelIdValue: channel_id, participantsValue: jsonString ?? "", groupNameValue: group_name, pttModeValue: "")
                    self.onNewChannel?(channel_id, channel_type, participantObjects, group_name)
                    AppData.shared.channelListData = talker_database.getChannelsList()
                }
            }
        }

    }
    
    public func onNewMessageReceived(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let id: String = dataObj?["id"] as? String ?? ""
            let sender_id: String = dataObj?["sender_id"] as? String ?? ""
            let sent_at: String = dataObj?["sent_at"] as? String ?? ""
            let channel_id: String = dataObj?["channel_id"] as? String ?? ""
            var channel_name: String = dataObj?["channel_name"] as? String ?? ""
            var sender_name: String = dataObj?["sender_name"] as? String ?? ""
            let description: String = dataObj?["description"] as? String ?? ""
//            let attachments = dataObj?["attachments"] as? String ?? ""
            let channelData = self.talker_database.getChannelsList().filter { $0.channelId == channel_id }
            
            if channelData.count >= 0 {
                channel_name = channelData[0].groupName ?? ""
            }
            
            let userData = self.talker_database.getUsersList().filter { $0.userId == sender_id }
            
            if userData.count >= 0 {
                sender_name = userData[0].name ?? ""
            }
            
            var attachmentsValue = ""
            if let attachmentsDict = dataObj?["attachments"] as? [String: Any] {
                // Convert attachments dictionary to JSON string
                if let attachmentsData = try? JSONSerialization.data(withJSONObject: attachmentsDict, options: []),
                   let attachmentsJSONString = String(data: attachmentsData, encoding: .utf8) {
                    attachmentsValue = attachmentsJSONString
                }
            }
            print(attachmentsValue)
            
            self.talker_database.addMessage(idValue: id, senderIdValue: sender_id, senderNameValue: sender_name, sentAtValue: sent_at, messageChannelIdValue: channel_id, messageChannelNameValue: channel_name, descriptionValue: description, attachmentsValue: attachmentsValue)
        }

    }
    
    public func onChannelUpdated(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
            let new_name : String = dataObj?["new_name"] as? String ?? ""
            
            self.talker_database.updateChannelName(channelIdValue: channel_id, newGroupName: new_name)
            self.onChannelUpdated?(new_name)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
    }
    
    public func onRemovedUserFromChannel(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
            let removed_participant = dataObj?["removed_participant"] as? String ?? ""
          
            self.talker_database.removeParticipant(channelIdValue: channel_id, participantIdToRemove: removed_participant)
            let loginUserid = "\(UserDefaults.standard.value(forKey: "userId") ?? "")"
            
            if loginUserid == removed_participant {
                self.talker_database.removeChannel(channelId: channel_id)
            }
            self.onRemovedUserFromChannel?(removed_participant)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
    }
    
    public func onAddedUserInChannel(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            // Decode JSON string to dictionary
            let dataObj = datString?.decodeJSONString()
            let channel_id: String = dataObj?["channel_id"] as? String ?? ""
            let newParticipants = dataObj?["new_participants"] as? [[String: Any]] ?? []
            
            // Print the new participants JSON
            print("New Participants: \(newParticipants)")
            
            // Add each new participant to the channel
            for participant in newParticipants {
                self.talker_database.addParticipant(channelIdValue: channel_id, newParticipant: participant)
            }
            
            self.onAddedUserInChannel?(newParticipants)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
        
    }
    
    public func onAdminAdded(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
            let new_admin = dataObj?["new_admin"] as? String ?? ""
          
            self.talker_database.addAdmin(channelIdValue: channel_id, participantIdToPromote: new_admin)
            self.onAdminAdded?(new_admin)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
    }
    
    public func onAdminRemoved(data: [Any]) {
        if data.count > 0 {
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
            let admin_removed = dataObj?["admin_removed"] as? String ?? ""
            self.talker_database.removeAdmin(channelIdValue: channel_id, participantIdToDemote: admin_removed)
            self.onAdminRemoved?(admin_removed)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
    }
    
//    func onRemovedChannel(data: [Any]) {
//        if data.count > 0 {
//            let datString = data[0] as? String
//            let dataObj = datString?.decodeJSONString()
//            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
//        }
//    }
}
