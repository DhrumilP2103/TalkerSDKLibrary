//
//  GetChannelListModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 20/08/24.
//

import Foundation

public struct GetChannelListModel: Codable {

    public var success : Bool? = nil
    public var data    : GetChannelListData? = GetChannelListData()

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
    data    = try values.decodeIfPresent(GetChannelListData.self , forKey: .data    )
 
  }

  init() {

  }

}

public struct GetParticipants: Codable {

    public var userId : String? = nil
    public var name   : String? = nil
    public var admin  : Bool?   = nil

  enum CodingKeys: String, CodingKey {

    case userId = "user_id"
    case name   = "name"
    case admin  = "admin"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    userId = try values.decodeIfPresent(String.self , forKey: .userId )
    name   = try values.decodeIfPresent(String.self , forKey: .name   )
    admin  = try values.decodeIfPresent(Bool.self   , forKey: .admin  )
 
  }

    public init(userId: String? = nil, name: String? = nil, admin: Bool? = nil) {
        self.userId = userId
        self.name = name
        self.admin = admin
  }

}

public struct GetChannels: Codable {

    public var channelId    : String?         = nil
    public var channelType  : String?         = nil
    public var participants : [GetParticipants]? = []
    public var groupName    : String?         = nil

  enum CodingKeys: String, CodingKey {

    case channelId    = "channel_id"
    case channelType  = "channel_type"
    case participants = "participants"
    case groupName    = "group_name"
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    channelId    = try values.decodeIfPresent(String.self         , forKey: .channelId    )
    channelType  = try values.decodeIfPresent(String.self         , forKey: .channelType  )
    participants = try values.decodeIfPresent([GetParticipants].self , forKey: .participants )
    groupName    = try values.decodeIfPresent(String.self         , forKey: .groupName    )
 
  }

    init(channelId: String? = nil, channelType: String? = nil, participants: [GetParticipants]? = [], groupName: String? = nil) {
        self.channelId = channelId
        self.channelType = channelType
        self.participants = participants
        self.groupName = groupName
    }

}

public struct GetChannelListData: Codable {

    public var channels : [GetChannels]? = []

  enum CodingKeys: String, CodingKey {

    case channels = "channels"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    channels = try values.decodeIfPresent([GetChannels].self , forKey: .channels )
 
  }

  init() {

  }

}
