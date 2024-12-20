//
//  APIService.swift
//  Talker SDK
//
//  Created by Kiran Jamod on 27/05/24.
//

import UIKit
import Alamofire

public class APIService {
    public init(){}
    public func getURLRequest(endPoint:String, isUpdateApn: Bool = false) -> URLRequest{
        var request = URLRequest(url: URL(string: "\(baseUrl + endPoint)")!)
        request.httpMethod = "POST"
        
        // HTTP Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if isUpdateApn {
            request.addValue(UserDefaults.standard.value(forKey: "user_auth_token") as! String, forHTTPHeaderField: "Authorization")
        } else {
            request.addValue("dd1fad96-0c8b-4600-8dc0-e9caeaa21bad", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    public func SdkCreateUserAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (CreateUserModel,Int,Bool) -> (), onError: @escaping @Sendable (ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: sdk_create_user_url)
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(CreateUserModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(CreateUserModel(), 101, false)
            }
        }.resume()
    }
    
    public func uploadTextAPI(parameter:[String:AnyObject],channelId: String , completion : @escaping @Sendable (UploadMessageModel,Int,Bool) -> (), onError: @escaping @Sendable (ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: "\(chat_upload_channel_id_url)\(channelId)", isUpdateApn: true)
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(UploadMessageModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(UploadMessageModel(), 101, false)
            }
        }.resume()
    }
    
    public func SdkSetUserAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (CreateUserModel,Int,Bool) -> (), onError: @escaping @Sendable (ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: sdk_set_user_url)
        request.httpMethod = "PUT"
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(CreateUserModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(CreateUserModel(), 101, false)
            }
        }.resume()
    }
    
    public func UpdateApnsPttAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (UpdateApnsPttModel,Int,Bool) -> (), onError: @escaping @Sendable(ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: update_apns_ptt_url, isUpdateApn: true)
        request.httpMethod = "PUT"
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(UpdateApnsPttModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(UpdateApnsPttModel(), 101, false)
            }
        }.resume()
    }
    
    public func TestApnsPttAPI(parameter:[String:AnyObject],fcm: String = "", completion : @escaping @Sendable(TestApnsPttModel,Int,Bool) -> (), onError: @escaping @Sendable(ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: "\(test_apns_ptt_url)?fcm_token=\(fcm)")
        request.httpMethod = "GET"
        DEBUGLOG("API Name :::::::::::::::::: \(request.url?.absoluteString ?? "")")
        
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(TestApnsPttModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(TestApnsPttModel(), 101, false)
            }
        }.resume()
    }
    
    public func SdkCredAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (SdkCredModel,Int,Bool) -> (), onError: @escaping @Sendable(ErrorModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: "\(sdk_cred_url)")
        request.httpMethod = "GET"
        DEBUGLOG("API Name :::::::::::::::::: \(request.url?.absoluteString ?? "")")
        
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(SdkCredModel.self, from: data)
                    if httpResponse?.statusCode == 500 {
                        onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "something went wrong on server"), httpResponse?.statusCode ?? 0, false)
                    } else {
                        completion(model,httpResponse?.statusCode ?? 0,true)
                    }
                } catch {
                    DEBUGLOG(error)
                    onError(ErrorModel(statusCode: httpResponse?.statusCode ?? 0, message: "\(error)"), httpResponse?.statusCode ?? 0, false)
//                    completion(CreateUserModel(),httpResponse?.statusCode ?? 0,false)
                }
            } else {
                /// Response Not Get
                completion(SdkCredModel(), 101, false)
            }
        }.resume()
    }
    
    public func GetAllUserAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (ListOfUsersModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: "\(sdk_users_url)")
        request.httpMethod = "GET"
        DEBUGLOG("API Name :::::::::::::::::: \(request.url?.absoluteString ?? "")")
        
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(ListOfUsersModel.self, from: data)
                    completion(model,httpResponse?.statusCode ?? 0,true)
                } catch {
                    DEBUGLOG(error)
                }
            }
        }.resume()
    }
    
    public func GetChannelListAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (GetChannelListModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: "\(chat_channels_url)", isUpdateApn: true)
        request.httpMethod = "GET"
        DEBUGLOG("API Name :::::::::::::::::: \(request.url?.absoluteString ?? "")")
        
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(GetChannelListModel.self, from: data)
                    completion(model,httpResponse?.statusCode ?? 0,true)
                } catch {
                    DEBUGLOG(error)
                }
            }
        }.resume()
    }
    
    public func leaveChannelAPI(channel_id: String, completion : @escaping @Sendable (ExitRoomModel,Int,Bool) -> ()){
        var request = getURLRequest(endPoint: "\(exit_room_url)", isUpdateApn: true)
        request.httpMethod = "DELETE"
        
        // JSON data
        let parameters: [String: String] = ["channel_id": channel_id]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            print("Failed to encode parameters to JSON: \(error)")
            return
        }
        
        DEBUGLOG("API Name :::::::::::::::::: \(request.url?.absoluteString ?? "")")
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(ExitRoomModel.self, from: data)
                    completion(model,httpResponse?.statusCode ?? 0,true)
                } catch {
                    DEBUGLOG(error)
                }
            }
        }.resume()
    }
  
    public func CreateDirectChannelAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (CreateDirectChannelModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: chat_channel_url, isUpdateApn: true)
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(CreateDirectChannelModel.self, from: data)
                        completion(model,httpResponse?.statusCode ?? 0,true)
                } catch {
                    DEBUGLOG(error)
                }
            }
        }.resume()
    }

    public func EditChannelDataAPI(parameter:[String:AnyObject], completion : @escaping @Sendable (EditChannelModel,Int,Bool) -> ()){
        
        var request = getURLRequest(endPoint: chat_channel_url, isUpdateApn: true)
        request.httpMethod = "PUT"
        
        DEBUGLOG("URL => \(request.url?.absoluteString ?? "")")
        DEBUGLOG("parameter => \(parameter)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            return
        }
        request.httpBody = httpBody
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let data = data {
                let httpResponse = response as? HTTPURLResponse
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    DEBUGLOG(json)
                    
                    let jsonDecoder = JSONDecoder()
                    let model = try jsonDecoder.decode(EditChannelModel.self, from: data)
                    completion(model,httpResponse?.statusCode ?? 0,true)
                } catch {
                    DEBUGLOG(error)
                }
            }
        }.resume()
    }
}

extension APIService {
    public func makePostHeaderImageCall(url: String, parameters: [String: Any], isVideo: Bool = false, completionHandler: @escaping @Sendable(AnyObject?, NSError?) -> ()) {

        let token : String = UserDefaults.standard.value(forKey: "user_auth_token") as! String
        let headers: HTTPHeaders = [
            "Authorization": "\(token)"
        ]
        
        DEBUGLOG("API Name :::::::::::::::::: \(url)")
        DEBUGLOG("Parameters ::::::::::::::::::")
        DEBUGLOG(parameters)
        DEBUGLOG("::::::::::::::::::")
        
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                if let image = value as? UIImage {
                    if image != UIImage(){
                        
                        multipartFormData.append(image.jpegData(compressionQuality: 0.5)!, withName: key,fileName: ".jpg", mimeType: "image/jpg")
                        
                    } else {
                        
                    }
                } else if let image = value as? Data {
                    if isVideo {
//                        multipartFormData.append(videoData, withName: "video", fileName: "\(strTimeStamp).mp4", mimeType: "video/mp4")
                        multipartFormData.append(image, withName: key,fileName: ".mp4", mimeType: "video/mp4")
                    } else {
                        multipartFormData.append(image, withName: key,fileName: ".pdf", mimeType: "application/pdf")
                    }
                }
                else {
                    // obj is String
                    multipartFormData.append((value as AnyObject).data(using: String.Encoding.utf8.rawValue)!, withName: key)
                }
            }
        },
                  to: url,
                  method: HTTPMethod.post,
                  headers: headers).responseData(queue: .main) { (response) in

            switch response.result {
                
            case .success(_):
//                DEBUGLOG(response)
                DEBUGLOG(String(decoding: response.value ?? Data(), as: UTF8.self))
                if let value = response.value {
                    let statusCode = response.response?.statusCode
                    if statusCode == 200 {
                        let dictString = String(decoding: value, as: UTF8.self)
                        DEBUGLOG(dictString)
                        completionHandler(dictString as AnyObject, nil)
                    } else{
                        let error = NSError(domain: "com.eezytutorials.iosTuts", code: (response.response?.statusCode)!, userInfo: ["Error reason" : "Invalid Outut"])
                        completionHandler(nil, error)
                    }
                }
                
            case .failure(_):
                let error = NSError(domain: "com.eezytutorials.iosTuts", code: (response.response?.statusCode ?? 0), userInfo: ["Error reason" : "Invalid Outut"])
                completionHandler(nil, error as NSError)
            }
        }
    }
}
