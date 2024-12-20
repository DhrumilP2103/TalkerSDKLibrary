//
//  SdkCredModel.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 10/06/24.
//

import Foundation

public struct SdkCredModel: Codable {

    public var success : Bool? = nil
    public var data    : SdkCredData? = SdkCredData()

  enum CodingKeys: String, CodingKey {

    case success = "success"
    case data    = "data"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    success = try values.decodeIfPresent(Bool.self , forKey: .success )
    data    = try values.decodeIfPresent(SdkCredData.self , forKey: .data    )
 
  }

  init() {

  }

}

public struct GeneralChannel: Codable {

    public var channelId   : String? = nil
    public var channelName : String? = nil

  enum CodingKeys: String, CodingKey {

    case channelId   = "channel_id"
    case channelName = "channel_name"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    channelId   = try values.decodeIfPresent(String.self , forKey: .channelId   )
    channelName = try values.decodeIfPresent(String.self , forKey: .channelName )
 
  }

  init() {

  }

}

public struct CognitoIdentityDefault: Codable {

    public  var PoolId : String? = nil
    public var Region : String? = nil

  enum CodingKeys: String, CodingKey {

    case PoolId = "PoolId"
    case Region = "Region"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    PoolId = try values.decodeIfPresent(String.self , forKey: .PoolId )
    Region = try values.decodeIfPresent(String.self , forKey: .Region )
 
  }

  init() {

  }

}

public struct CredentialCognitoIdentity: Codable {

    public var Default : CognitoIdentityDefault? = CognitoIdentityDefault()

  enum CodingKeys: String, CodingKey {

    case Default = "Default"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    Default = try values.decodeIfPresent(CognitoIdentityDefault.self , forKey: .Default )
 
  }

  init() {

  }

}


public struct SDKCredentialsProvider: Codable {

    public  var CognitoIdentity : CredentialCognitoIdentity? = CredentialCognitoIdentity()

  enum CodingKeys: String, CodingKey {

    case CognitoIdentity = "CognitoIdentity"
  
  }

    public  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    CognitoIdentity = try values.decodeIfPresent(CredentialCognitoIdentity.self , forKey: .CognitoIdentity )
 
  }

  init() {

  }

}

public struct IdentityManagerDefault: Codable {


//  enum CodingKeys: String, CodingKey {
//
//  
//  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

 
  }

  init() {

  }

}
import Foundation

public struct SDKIdentityManager: Codable {

    public var Default : IdentityManagerDefault? = IdentityManagerDefault()

  enum CodingKeys: String, CodingKey {

    case Default = "Default"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    Default = try values.decodeIfPresent(IdentityManagerDefault.self , forKey: .Default )
 
  }

  init() {

  }

}

public struct CognitoUserPoolDefault: Codable {

    public var AppClientSecret : String? = nil
    public var AppClientId     : String? = nil
    public var PoolId          : String? = nil
    public var Region          : String? = nil

  enum CodingKeys: String, CodingKey {

    case AppClientSecret = "AppClientSecret"
    case AppClientId     = "AppClientId"
    case PoolId          = "PoolId"
    case Region          = "Region"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    AppClientSecret = try values.decodeIfPresent(String.self , forKey: .AppClientSecret )
    AppClientId     = try values.decodeIfPresent(String.self , forKey: .AppClientId     )
    PoolId          = try values.decodeIfPresent(String.self , forKey: .PoolId          )
    Region          = try values.decodeIfPresent(String.self , forKey: .Region          )
 
  }

  init() {

  }

}

public struct SDKCognitoUserPool: Codable {

    public var Default : CognitoUserPoolDefault? = CognitoUserPoolDefault()

  enum CodingKeys: String, CodingKey {

    case Default = "Default"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    Default = try values.decodeIfPresent(CognitoUserPoolDefault.self , forKey: .Default )
 
  }

  init() {

  }

}

public struct Cognito: Codable {

    public var Version             : String?              = nil
    public var CredentialsProvider : SDKCredentialsProvider? = SDKCredentialsProvider()
    public var IdentityManager     : SDKIdentityManager?     = SDKIdentityManager()
    public var CognitoUserPool     : SDKCognitoUserPool?     = SDKCognitoUserPool()

  enum CodingKeys: String, CodingKey {

    case Version             = "Version"
    case CredentialsProvider = "CredentialsProvider"
    case IdentityManager     = "IdentityManager"
    case CognitoUserPool     = "CognitoUserPool"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    Version             = try values.decodeIfPresent(String.self              , forKey: .Version             )
    CredentialsProvider = try values.decodeIfPresent(SDKCredentialsProvider.self , forKey: .CredentialsProvider )
    IdentityManager     = try values.decodeIfPresent(SDKIdentityManager.self     , forKey: .IdentityManager     )
    CognitoUserPool     = try values.decodeIfPresent(SDKCognitoUserPool.self     , forKey: .CognitoUserPool     )
 
  }

  init() {

  }

}

public struct SdkCredData: Codable {

    public var generalChannel    : GeneralChannel? = GeneralChannel()
    public var cognito           : Cognito?        = Cognito()
    public var webrtcChannelName : String?         = nil

  enum CodingKeys: String, CodingKey {

    case generalChannel    = "general_channel"
    case cognito           = "cognito"
    case webrtcChannelName = "webrtc_channel_name"
  
  }

    public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    generalChannel    = try values.decodeIfPresent(GeneralChannel.self , forKey: .generalChannel    )
    cognito           = try values.decodeIfPresent(Cognito.self        , forKey: .cognito           )
    webrtcChannelName = try values.decodeIfPresent(String.self         , forKey: .webrtcChannelName )
 
  }

  init() {

  }

}
