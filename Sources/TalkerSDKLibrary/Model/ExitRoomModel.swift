//
//  ExitRoomModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 30/08/24.
//

import Foundation

public struct ExitRoomModel: Codable {

    public var message : String? = nil
    public var data    : ExitRoomData?   = ExitRoomData()
    public var success : Bool?   = nil

  enum CodingKeys: String, CodingKey {

    case message = "message"
    case data    = "data"
    case success = "success"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    message = try values.decodeIfPresent(String.self , forKey: .message )
    data    = try values.decodeIfPresent(ExitRoomData.self   , forKey: .data    )
    success = try values.decodeIfPresent(Bool.self   , forKey: .success )
 
  }

  init() {

  }

}

public struct ExitRoomData: Codable {

    public var errorCode : Int? = nil

  enum CodingKeys: String, CodingKey {

    case errorCode = "error_code"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    errorCode = try values.decodeIfPresent(Int.self , forKey: .errorCode )
 
  }

  init() {

  }

}
