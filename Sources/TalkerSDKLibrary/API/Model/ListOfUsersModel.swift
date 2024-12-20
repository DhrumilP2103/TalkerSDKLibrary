//
//  ListOfUsersModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 20/08/24.
//

import Foundation

public struct ListOfUsersModel: Codable {

    public var success : Bool?   = nil
    public var data    : [ListOfUsersData]? = []

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self   , forKey: .success )
    data    = try values.decodeIfPresent([ListOfUsersData].self , forKey: .data    )
 
  }

  init() {

  }

}

public struct ListOfUsersData: Codable {

    public var name   : String? = nil
    public var userId : String? = nil

  enum CodingKeys: String, CodingKey {

    case name   = "name"
    case userId = "user_id"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    name   = try values.decodeIfPresent(String.self , forKey: .name   )
    userId = try values.decodeIfPresent(String.self , forKey: .userId )
 
  }

  init() {

  }

}
