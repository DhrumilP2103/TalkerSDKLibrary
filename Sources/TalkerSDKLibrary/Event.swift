import Foundation
import WebRTC

internal class Event {
    public class func parseEvent(event: String) -> Message? {
        do {
            //            print("Event = \(event)")
            
            let payLoad = try event.convertToDictionaryValueAsString()
            
            if payLoad.count >= 2 {
//                print(payLoad)
                
                let messageType: String = payLoad["messageType"]! as! String
                let messagePayload: String = payLoad["messagePayload"]! as! String
                if let senderClientId = payLoad["senderClientId"] {
                    print("senderClientId : \(senderClientId)")
                    return Message(messageType, "", senderClientId as! String, messagePayload)
                } else {
                    return Message(messageType, "", "", messagePayload)
                }
            }
            
        } catch {
            print("payload Error \(error)")
        }
        return nil
    }
}

extension String {
    public func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }
    
    public func base64Decoded() -> String? {
//        print("decode base64") 
        
        var localData: Data?
        localData = Data(base64Encoded: self)
        var temp: String = self
        if localData == nil {
            temp = self + "=="
        }
        guard let data = Data(base64Encoded: temp, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    public func convertToDictionaryValueAsString() throws -> [String: Any] {
        let data = Data(utf8)
        
        if let anyResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return anyResult
        } else {
            return [:]
        }
    }
    
    
    func decodeJSONString() -> [String: Any]? {
        // Step 1: Replace escaped backslashes with actual backslashes
        var cleanJSONString = self.replacingOccurrences(of: "\\\\", with: "\\")
        
        // Step 2: Replace escaped double quotes with actual double quotes
        cleanJSONString = cleanJSONString.replacingOccurrences(of: "\\\"", with: "\"")
        
        // Step 3: Remove enclosing quotes if present
        cleanJSONString = cleanJSONString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        // Step 4: Replace escaped newlines with actual newlines
        //                cleanJSONString = cleanJSONString.replacingOccurrences(of: "\\r\\n", with: "\r\n")
        
        // Step 5: Convert the cleaned JSON string to Data
        
        guard let data = cleanJSONString.data(using: .utf8) else {
            print("Failed to convert string to Data")
            return nil
        }
        
        // Step 6: Decode the Data to a dictionary
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            if let jsonDict = jsonObject as? [String: Any] {
                return jsonDict
            } else {
                print("Failed to cast JSON object to dictionary")
                return nil
            }
        } catch {
            print("Failed to decode JSON: \(error)")
            return nil
        }
    }
}

