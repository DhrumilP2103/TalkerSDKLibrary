//
//  TestApnsPttModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 27/05/24.
//

import Foundation

public struct TestApnsPttModel: Codable {

    public var data : TestApnsPttData? = TestApnsPttData()

  enum CodingKeys: String, CodingKey {

    case data = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    data = try values.decodeIfPresent(TestApnsPttData.self , forKey: .data )
 
  }

  init() {

  }

}

public struct TestApnsPttData: Codable {

    public var testing : String? = nil

  enum CodingKeys: String, CodingKey {

    case testing = "testing"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    testing = try values.decodeIfPresent(String.self , forKey: .testing )
 
  }

  init() {

  }

}
