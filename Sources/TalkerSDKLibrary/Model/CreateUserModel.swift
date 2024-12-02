//
//  CreateUserModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 27/05/24.
//

import Foundation

public struct CreateUserModel: Codable {

    public var success : Bool? = nil
    public var data    : CreateUserModelData? = CreateUserModelData()

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
    data    = try values.decodeIfPresent(CreateUserModelData.self , forKey: .data    )
 
  }

  init() {

  }

}

public struct CreateUserModelData: Codable {

    public var name          : String? = nil
    public var aUsername     : String? = nil
    public var aPass         : String? = nil
    public var userId        : String? = nil
    public var userAuthToken : String? = nil

  enum CodingKeys: String, CodingKey {

    case name          = "name"
    case aUsername     = "a_username"
    case aPass         = "a_pass"
    case userId        = "user_id"
    case userAuthToken = "user_auth_token"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    name          = try values.decodeIfPresent(String.self , forKey: .name          )
    aUsername     = try values.decodeIfPresent(String.self , forKey: .aUsername     )
    aPass         = try values.decodeIfPresent(String.self , forKey: .aPass         )
    userId        = try values.decodeIfPresent(String.self , forKey: .userId        )
    userAuthToken = try values.decodeIfPresent(String.self , forKey: .userAuthToken )
 
  }

  init() {

  }

}
