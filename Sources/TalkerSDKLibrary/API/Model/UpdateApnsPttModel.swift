//
//  UpdateApnsPttModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 27/05/24.
//

import Foundation

public struct UpdateApnsPttModel: Codable {

  var success : Bool? = nil

  enum CodingKeys: String, CodingKey {

    case success = "success"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
 
  }

  init() {

  }

}
