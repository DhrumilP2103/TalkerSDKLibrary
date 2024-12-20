import Foundation
import SQLite

public class Talker_Database {
    
    // SQLite instance
    private var db: Connection!
    
    // Table instances
    private var usersList: Table!
    private var channelList: Table!
    private var messageList: Table!
    
    // Column instances of user table
    private var name: SQLite.Expression<String>!
    private var userId: SQLite.Expression<String>!
    
    // Column instances of channel table
    private var channelType: SQLite.Expression<String>!
    private var channelId: SQLite.Expression<String>!
    private var participants: SQLite.Expression<String>! // Store as JSON string
    private var groupName: SQLite.Expression<String>!
    private var pttMode: SQLite.Expression<String>!
    
    // Column instances of meassage table
    private var id: SQLite.Expression<String>!
    private var senderId: SQLite.Expression<String>!
    private var senderName: SQLite.Expression<String>!
    private var sentAt: SQLite.Expression<String>!
    private var meassageChannelId: SQLite.Expression<String>!
    private var meassageChannelName: SQLite.Expression<String>!
    private var description: SQLite.Expression<String>!
    private var attachments: SQLite.Expression<String>! // Store as JSON string
    
    // Constructor of this class
    init () {
        
        // Exception handling
        do {
            // Path of document directory
            let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
            
            // Creating database connection
            db = try Connection("\(path)/my_users.sqlite3")
            
            // Creating table objects
            usersList = Table("users")
            channelList = Table("channels")
            messageList = Table("messageList")
            
            // Create instances of each column for user table
            name = Expression<String>("name")
            userId = Expression<String>("userId")
            
            // Create instances of each column for channel table
            channelType = Expression<String>("channelType")
            channelId = Expression<String>("channelId")
            participants = Expression<String>("participants") // Store as JSON string
            groupName = Expression<String>("groupName")
            pttMode = Expression<String>("pttMode")
            
            id = Expression<String>("id")
            senderId = Expression<String>("senderId")
            senderName = Expression<String>("senderName")
            sentAt = Expression<String>("sentAt")
            meassageChannelId = Expression<String>("meassageChannelId")
            meassageChannelName = Expression<String>("meassageChannelName")
            description = Expression<String>("description")
            attachments = Expression<String>("attachments")
            
            // Create tables if they don't exist
            try db.run(usersList.create(ifNotExists: true) { (t) in
                t.column(name)
                t.column(userId, primaryKey: true)
            })
            
            try db.run(channelList.create(ifNotExists: true) { (t) in
                t.column(channelType)
                t.column(channelId, primaryKey: true)
                t.column(participants)
                t.column(groupName)
                t.column(pttMode)
            })
            
            try db.run(messageList.create(ifNotExists: true) { (t) in
                t.column(id)
                t.column(senderId)
                t.column(senderName)
                t.column(sentAt)
                t.column(meassageChannelId)
                t.column(meassageChannelName)
                t.column(description)
                t.column(attachments)
                
            })
            
        } catch {
            // Show error message if any
            print(error.localizedDescription)
        }
    }

}

//MARK: -  Users Query
extension Talker_Database {
    
    public func addUser(nameValue: String, userIdValue: String) {
        do {
            try db.run(usersList.insert(name <- nameValue, userId <- userIdValue))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // Return array of user models for all users
    public func getUsersList() -> [UserListData] {
        
        // Create empty array
        var userListDatas: [UserListData] = []
        
        // Exception handling
        do {
            // Loop through all users
            for user in try db.prepare(usersList) {
                // Create new model in each loop iteration
                let userListData = UserListData(name: user[name], userId: user[userId])
                
                // Append in new array
                userListDatas.insert(userListData, at: 0)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        // Return array
        return userListDatas
    }
    
    // Delete all users
    public func deleteAllUsers() {
        do {
            try db.run(usersList.delete())
        } catch {
            print(error.localizedDescription)
        }
    }
    
}

//MARK: -  Channels Query
extension Talker_Database {
    
    // Add a new channel
    public func addChannel(channelTypeValue: String, channelIdValue: String, participantsValue: String, groupNameValue: String, pttModeValue: String) {
        do {
            // Run the insert statement with the pttMode value
            try db.run(channelList.insert(
                channelType <- channelTypeValue,
                channelId <- channelIdValue,
                participants <- participantsValue,
                groupName <- groupNameValue,
                pttMode <- pttModeValue
            ))
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    public func updateChannelName(channelIdValue: String, newGroupName: String) {
        do {
            // Find the channel by channelId and update its groupName
            let channel = channelList.filter(channelId == channelIdValue)
            try db.run(channel.update(groupName <- newGroupName))
            
            print("Channel name updated to: \(newGroupName)")
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    public func addParticipant(channelIdValue: String, newParticipant: [String: Any]) {
        do {
            // Find the channel by channelId
            let channel = channelList.filter(channelId == channelIdValue)
            
            // Fetch the current participants
            if let currentParticipantsJson = try db.pluck(channel.select(participants))?[participants] {
                
                // Convert JSON string to array
                if let data = currentParticipantsJson.data(using: .utf8) {
                    do {
                        // Attempt to parse the JSON data
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        // Check if the JSON object is an array
                        if var participantsArray = jsonObject as? [[String: Any]] {
                            
                            // Append new participant dictionary
                            participantsArray.append(newParticipant)
                            
                            // Convert back to JSON string
                            let updatedParticipantsData = try JSONSerialization.data(withJSONObject: participantsArray, options: [])
                            let updatedParticipantsJson = String(data: updatedParticipantsData, encoding: .utf8) ?? "[]"
                            
                            // Update the participants in the database
                            try db.run(channel.update(participants <- updatedParticipantsJson))
                        } else {
                            print("Error: JSON is not an array of dictionaries. It is: \(type(of: jsonObject))")
                        }
                    } catch {
                        print("Error converting JSON string to array: \(error.localizedDescription)")
                    }
                } else {
                    print("Error: Failed to convert JSON string to Data")
                }
            } else {
                // Handle the case where the channel doesn't have any participants yet
                let newParticipantsArray = [newParticipant]
                let newParticipantsData = try JSONSerialization.data(withJSONObject: newParticipantsArray, options: [])
                let newParticipantsJson = String(data: newParticipantsData, encoding: .utf8) ?? "[]"
                try db.run(channel.update(participants <- newParticipantsJson))
                
                print("Participant added to channel with ID: \(channelIdValue) (new channel)")
            }
            
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    public func removeParticipant(channelIdValue: String, participantIdToRemove: String) {
        do {
            // Find the channel by channelId
            let channel = channelList.filter(channelId == channelIdValue)
            
            // Fetch the current participants
            if let currentParticipantsJson = try db.pluck(channel.select(participants))?[participants] {
                // Convert JSON string to array of dictionaries
                if let data = currentParticipantsJson.data(using: .utf8) {
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        if var participantsArray = jsonObject as? [[String: Any]] {
                            // Remove the participant with the given ID
                            participantsArray = participantsArray.filter { $0["user_id"] as? String != participantIdToRemove }
                            
                            // Convert back to JSON string
                            let updatedParticipantsData = try JSONSerialization.data(withJSONObject: participantsArray, options: [])
                            let updatedParticipantsJson = String(data: updatedParticipantsData, encoding: .utf8) ?? "[]"
                            
                            // Update the participants in the database
                            try db.run(channel.update(participants <- updatedParticipantsJson))
                        } else {
                            print("Error: JSON is not an array of dictionaries. It is: \(type(of: jsonObject))")
                        }
                    } catch {
                        print("Error converting JSON string to array: \(error.localizedDescription)")
                    }
                } else {
                    print("Error: Failed to convert JSON string to Data")
                }
            } else {
                print("Error: No participants found for channel with ID: \(channelIdValue)")
            }
            
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }


    public func addAdmin(channelIdValue: String, participantIdToPromote: String) {
        do {
            // Find the channel by channelId
            let channel = channelList.filter(channelId == channelIdValue)
            
            // Fetch the current participants
            if let currentParticipantsJson = try db.pluck(channel.select(participants))?[participants] {
                // Convert JSON string to array of dictionaries
                if let data = currentParticipantsJson.data(using: .utf8) {
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        if var participantsArray = jsonObject as? [[String: Any]] {
                            // Update the admin status for the specified participant
                            for i in 0..<participantsArray.count {
                                var participant = participantsArray[i]
                                if participant["user_id"] as? String == participantIdToPromote {
                                    participant["admin"] = true
                                    participantsArray[i] = participant
                                    break
                                }
                            }
                            
                            // Convert back to JSON string
                            let updatedParticipantsData = try JSONSerialization.data(withJSONObject: participantsArray, options: [])
                            let updatedParticipantsJson = String(data: updatedParticipantsData, encoding: .utf8) ?? "[]"
                            
                            // Update the participants in the database
                            try db.run(channel.update(participants <- updatedParticipantsJson))
                        } else {
                            print("Error: JSON is not an array of dictionaries. It is: \(type(of: jsonObject))")
                        }
                    } catch {
                        print("Error converting JSON string to array: \(error.localizedDescription)")
                    }
                } else {
                    print("Error: Failed to convert JSON string to Data")
                }
            } else {
                print("Error: No participants found for channel with ID: \(channelIdValue)")
            }
            
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    public func removeAdmin(channelIdValue: String, participantIdToDemote: String) {
        do {
            // Find the channel by channelId
            let channel = channelList.filter(channelId == channelIdValue)
            
            // Fetch the current participants
            if let currentParticipantsJson = try db.pluck(channel.select(participants))?[participants] {
                // Convert JSON string to array of dictionaries
                if let data = currentParticipantsJson.data(using: .utf8) {
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        if var participantsArray = jsonObject as? [[String: Any]] {
                            // Update the admin status for the specified participant
                            for i in 0..<participantsArray.count {
                                var participant = participantsArray[i]
                                if participant["user_id"] as? String == participantIdToDemote {
                                    participant["admin"] = false
                                    participantsArray[i] = participant
                                    break
                                }
                            }
                            
                            // Convert back to JSON string
                            let updatedParticipantsData = try JSONSerialization.data(withJSONObject: participantsArray, options: [])
                            let updatedParticipantsJson = String(data: updatedParticipantsData, encoding: .utf8) ?? "[]"
                            
                            // Update the participants in the database
                            try db.run(channel.update(participants <- updatedParticipantsJson))
                        } else {
                            print("Error: JSON is not an array of dictionaries. It is: \(type(of: jsonObject))")
                        }
                    } catch {
                        print("Error converting JSON string to array: \(error.localizedDescription)")
                    }
                } else {
                    print("Error: Failed to convert JSON string to Data")
                }
            } else {
                print("Error: No participants found for channel with ID: \(channelIdValue)")
            }
            
        } catch let Result.error(message, code, statement) {
            // Detailed SQLite error
            print("SQLite Error: \(message) (code: \(code)) at statement: \(statement?.description ?? "N/A")")
        } catch {
            // General error
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    // Remove Perticuler Channel
    public func removeChannel(channelId: String) {
        do {
            let channelToRemove = channelList.filter(self.channelId == channelId)
            try db.run(channelToRemove.delete())
            print("Channel removed successfully")
        } catch {
            print("Error removing channel: \(error.localizedDescription)")
        }
    }

    
    // Get all channels
    public func getChannelsList() -> [ChannelListData] {
        var channelListModels: [ChannelListData] = []
        
        do {
            for channel in try db.prepare(channelList) {
                let participantsString = channel[participants]
                let channelListData = ChannelListData(
                    channelType: channel[channelType],
                    channelId: channel[channelId],
                    participants: participantsString,
                    groupName: channel[groupName]
                )
                
                channelListModels.append(channelListData)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return channelListModels
    }
    
    // Delete all channels
    public func deleteAllChannels() {
        do {
            try db.run(channelList.delete())
        } catch {
            print(error.localizedDescription)
        }
    }
    
}

public class UserListData: Identifiable {
    
    public var name: String?
    public var userId: String?
    
    init(name: String? = nil, userId: String? = nil) {
        self.name = name
        self.userId = userId
    }
}

public class ChannelListData: Identifiable {

    public var channelType: String?
    public var channelId: String?
    public var participants: String? // Store as JSON string
    public var groupName: String?
    
    init(channelType: String? = nil, channelId: String? = nil, participants: String? = nil, groupName: String? = nil) {
        self.channelType = channelType
        self.channelId = channelId
        self.participants = participants
        self.groupName = groupName
    }
}

//MARK: -  Messages Query
extension Talker_Database {

    public func addMessage(idValue: String, senderIdValue: String, senderNameValue: String, sentAtValue: String, messageChannelIdValue: String, messageChannelNameValue: String, descriptionValue: String, attachmentsValue: String) {
        do {
            // Insert new message into messageList
            try db.run(messageList.insert(
                id <- idValue,
                senderId <- senderIdValue,
                senderName <- senderNameValue,
                sentAt <- sentAtValue,
                meassageChannelId <- messageChannelIdValue,
                meassageChannelName <- messageChannelNameValue,
                description <- descriptionValue,
                attachments <- attachmentsValue
            ))
            print("Done adding message")
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func getChannelMessages(channelIdValue: String) -> [MessageListData] {
        
        // Create empty array to store messages
        var messagesList: [MessageListData] = []
        
        // Exception handling
        do {
            // Query the messageList for a particular channel ID
            let query = messageList.filter(meassageChannelId == channelIdValue)
            
            // Loop through the filtered results
            for message in try db.prepare(query) {
                // Create new MessageData object
                let messageData = MessageListData(
                    id: message[id],
                    senderId: message[senderId],
                    senderName: message[senderName],
                    sentAt: message[sentAt],
                    messageChannelId: message[meassageChannelId],  // corrected typo
                    messageChannelName: message[meassageChannelName],  // corrected typo
                    description: message[description],
                    attachments: message[attachments]
                )
                
                // Append each message to the list
                messagesList.append(messageData)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        // Return the list of messages
        return messagesList
    }
    
    // Delete all messages
    public func deleteAllMessages() {
        do {
            try db.run(messageList.delete())
        } catch {
            print(error.localizedDescription)
        }
    }
}

public class MessageListData: Identifiable {

    public var id: String?
    public var senderId: String?
    public var senderName: String?
    public var sentAt: String?
    public var messageChannelId: String?
    public var messageChannelName: String?
    public var description: String?
    public var attachments: String? // Store as JSON string
    
    init(id: String? = nil, senderId: String? = nil, senderName: String? = nil, sentAt: String? = nil, messageChannelId: String? = nil, messageChannelName: String? = nil, description: String? = nil, attachments: String? = nil) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.sentAt = sentAt
        self.messageChannelId = messageChannelId
        self.messageChannelName = messageChannelName
        self.description = description
        self.attachments = attachments
    }
}
