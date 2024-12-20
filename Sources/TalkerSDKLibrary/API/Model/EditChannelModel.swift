//
//  EditChannelModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 20/08/24.
//

import Foundation

public struct EditChannelModel: Codable {

    public var success : Bool? = nil
    public var data    : EditChannelData? = EditChannelData()

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
    data    = try values.decodeIfPresent(EditChannelData.self , forKey: .data    )
 
  }

  init() {

  }

}

public struct EditChannelData: Codable {

    public var channelId : String? = nil
    public var newAdmin  : String? = nil
    public var adminRemoved : String? = nil
    public var newName : String? = nil
    public var newParticipants : [GetParticipants]? = []
    public var removedParticipant : String? = nil

  enum CodingKeys: String, CodingKey {

    case channelId = "channel_id"
    case newAdmin  = "new_admin"
    case adminRemoved = "admin_removed"
    case newName   = "new_name"
    case newParticipants = "new_participants"
    case removedParticipant = "removed_participant"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    channelId = try values.decodeIfPresent(String.self , forKey: .channelId )
    newAdmin  = try values.decodeIfPresent(String.self , forKey: .newAdmin  )
    adminRemoved = try values.decodeIfPresent(String.self , forKey: .adminRemoved )
    newName = try values.decodeIfPresent(String.self , forKey: .newName )
    newParticipants = try values.decodeIfPresent([GetParticipants].self , forKey: .newParticipants )
    removedParticipant = try values.decodeIfPresent(String.self , forKey: .removedParticipant )
 
  }

  init() {

  }

}
