//
//  CreateDirectChannelModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 20/08/24.
//

import Foundation

public struct CreateDirectChannelModel: Codable {

    public var success : Bool? = nil
    public var data    : CreateDirectChannelData? = CreateDirectChannelData()

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
    data    = try values.decodeIfPresent(CreateDirectChannelData.self , forKey: .data    )
 
  }

  init() {

  }

}


public struct CreateDirectChannelData: Codable {

    public var channelType  : String?         = nil
    public var channelId    : String?         = nil
    public var participants : [GetParticipants]? = []
    public var groupName    : String?         = nil
    public  var pttMode      : Bool?           = nil

  enum CodingKeys: String, CodingKey {

    case channelType  = "channel_type"
    case channelId    = "channel_id"
    case participants = "participants"
    case groupName    = "group_name"
    case pttMode      = "ptt_mode"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    channelType  = try values.decodeIfPresent(String.self         , forKey: .channelType  )
    channelId    = try values.decodeIfPresent(String.self         , forKey: .channelId    )
    participants = try values.decodeIfPresent([GetParticipants].self , forKey: .participants )
    groupName    = try values.decodeIfPresent(String.self         , forKey: .groupName    )
    pttMode      = try values.decodeIfPresent(Bool.self           , forKey: .pttMode      )
 
  }

  init() {

  }

}
