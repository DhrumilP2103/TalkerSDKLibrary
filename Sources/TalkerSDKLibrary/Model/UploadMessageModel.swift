//
//  UploadMessageModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 10/10/24.
//

import Foundation

public struct UploadMessageModel: Codable {

    public var success     : Bool?        = nil
    public var messageId   : String?      = nil
    public var description : String?      = nil
    public var attachments : UploadMessageAttachments? = UploadMessageAttachments()
    public var sentAt      : String?      = nil

  enum CodingKeys: String, CodingKey {

    case success     = "success"
    case messageId   = "message_id"
    case description = "description"
    case attachments = "attachments"
    case sentAt      = "sent_at"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success     = try values.decodeIfPresent(Bool.self        , forKey: .success     )
    messageId   = try values.decodeIfPresent(String.self      , forKey: .messageId   )
    description = try values.decodeIfPresent(String.self      , forKey: .description )
    attachments = try values.decodeIfPresent(UploadMessageAttachments.self , forKey: .attachments )
    sentAt      = try values.decodeIfPresent(String.self      , forKey: .sentAt      )
 
  }

  init() {

  }

}

public struct UploadMessageImages: Codable {

    public var url : String? = nil

  enum CodingKeys: String, CodingKey {

    case url = "url"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    url = try values.decodeIfPresent(String.self , forKey: .url )
 
  }

  init() {

  }

}

public struct UploadMessageAttachments: Codable {

  var images : [UploadMessageImages]? = []
  var document : [UploadMessageImages]? = []

  enum CodingKeys: String, CodingKey {

    case images = "images"
    case document = "document"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    images = try values.decodeIfPresent([UploadMessageImages].self , forKey: .images )
      document = try values.decodeIfPresent([UploadMessageImages].self , forKey: .document )
 
  }

  init() {

  }

}
