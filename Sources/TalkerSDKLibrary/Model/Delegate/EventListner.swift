//
//  EventListner.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 10/07/24.
//

import Foundation
import TalkerSDKLibrary
enum AudioStatus : String {
  case Connecting = "Connecting"
  case Busy = "Busy"
  case Sending = "Sending"
  case Stopped = "Stopped"
  
}

enum ServerConnectionState: String {
    case Success = "Success"
    case Failure = "Failure"
    case Closed = "Closed"
}

/// A protocol for listening to various events in the application.
protocol EventListnerDelegate {
    /// Called when the audio status changes.
    /// - Parameter audioStatus: The new audio status as an `AudioStatus` enum value.
    /// This method is triggered whenever there is a change in the audio status,
    /// allowing listeners to handle updates or changes accordingly.
    func onAudioStatusChange(audioStatus: AudioStatus)
    
    /// Called when the server connection state changes.
    /// - Parameters:
    ///   - serverConnectionState: The new state of the server connection as a `ServerConnectionState` enum value.
    ///   - message: An optional message providing additional information about the connection state change.
    /// This method is triggered whenever there is a change in the server connection status,
    /// allowing listeners to take appropriate actions based on the new connection state.
    func onServerConnectionChange(serverConnectionState: ServerConnectionState, message: String)
    
    /// Called when a new channel is created.
    /// - Parameter data: An array of data related to the newly created channel.
    /// This method is triggered when a new channel is successfully created,
    /// allowing listeners to process or respond to the creation event.
    func onNewChannelCreate(data : [Any])
    
    /// Called when an existing channel is updated.
    /// - Parameter data: An array of data related to the updated channel.
    /// This method is triggered whenever there are updates to an existing channel,
    /// allowing listeners to handle or respond to the changes accordingly.
    func onChannelUpdated(data : [Any])
    
    /// Called when the user is removed from a channel.
    /// - Parameter data: An array of data related to the removal from the channel.
    /// This method is triggered when the user is removed from a channel,
    /// allowing listeners to take necessary actions such as updating the UI or notifying the user.
    func onRemovedUserFromChannel(data : [Any])
    
    /// Called when the user is added to a channel.
    /// - Parameter data: An array of data related to the addition to the channel.
    /// This method is triggered when the user is added to a channel,
    /// allowing listeners to update the UI or perform actions based on the new channel membership.
    func onAddedUserInChannel(data : [Any])
    
    /// Called when an admin is added to a channel.
    /// - Parameter data: An array of data related to the new admin.
    /// This method is triggered when a new admin is added to a channel,
    /// allowing listeners to take appropriate actions or update the channel information.
    func onAdminAdded(data : [Any])
    
    /// Called when an admin is removed from a channel.
    /// - Parameter data: An array of data related to the removed admin.
    /// This method is triggered when an admin is removed from a channel,
    /// allowing listeners to update the channel information or notify users as needed.
    func onAdminRemoved(data : [Any])
    func onNewMessageReceived(data : [Any])
//    func onRemovedChannel(data : [Any])
    
    func currentPttAudio(sender_id: String, channel_id: String, channel_name: String, sender_name: String)
}

class EventListner: ObservableObject, EventListnerDelegate {
    
    @Published var onAudioStatus: ((AudioStatus)->())?
    @Published var onServerConnection: ((ServerConnectionState)->())?
    @Published var onNewChannel: ((_ channelId: String, _ channelType: String, _ participants: [GetParticipants], _ groupName: String)->())?
    @Published var onChannelUpdated: ((_ new_name: String)->())?
    @Published var onRemovedUserFromChannel: ((String)->())?
    @Published var onAddedUserInChannel: (([[String: Any]])->())?
    @Published var onAdminAdded: ((String)->())?
    @Published var onAdminRemoved: ((String)->())?
    @Published var currentPttAudio: ((_ sender_id: String, _ channel_id: String, _ channel_name: String, _ sender_name: String)->())?
    
    var talker_database = Talker_Database()
    
    func currentPttAudio(sender_id: String, channel_id: String, channel_name: String, sender_name: String) {
        self.currentPttAudio?(sender_id, channel_id, channel_name, sender_name)
    }
    
    func onAudioStatusChange(audioStatus: AudioStatus) {
        self.onAudioStatus?(audioStatus)
    }
    
    func onServerConnectionChange(serverConnectionState: ServerConnectionState, message: String) {
        self.onServerConnection?(serverConnectionState)
    }
   
    func onNewChannelCreate(data : [Any]) {
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
    
    func onNewMessageReceived(data : [Any]) {
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
    
    func onChannelUpdated(data : [Any]) {
        if data.count > 0{
            let datString = data[0] as? String
            let dataObj = datString?.decodeJSONString()
            let channel_id : String = dataObj?["channel_id"] as? String ?? ""
            let new_name : String = dataObj?["new_name"] as? String ?? ""
            
            self.talker_database.updateChannelName(channelIdValue: channel_id, newGroupName: new_name)
            self.onChannelUpdated?(new_name)
            AppData.shared.channelListData = talker_database.getChannelsList()
        }
    }
    
    func onRemovedUserFromChannel(data : [Any]) {
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
        
    func onAddedUserInChannel(data : [Any]) {
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
    
    func onAdminAdded(data: [Any]) {
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
    
    func onAdminRemoved(data: [Any]) {
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
