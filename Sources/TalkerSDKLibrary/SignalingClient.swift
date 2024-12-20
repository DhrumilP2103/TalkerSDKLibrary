import Foundation
import Starscream
import WebKit
import WebRTC

// interface for remote connectivity events
protocol SignalClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, senderClientId: String, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalingClient, senderClientId: String, didReceiveCandidate candidate: RTCIceCandidate)
}

internal class SignalingClient {
    private let socket: WebSocket
    private let encoder = JSONEncoder()
    weak var delegate: SignalClientDelegate?

    private let isPrintDebugData = false
    
    init(serverUrl: URL) {
        var request: URLRequest = URLRequest(url: serverUrl)

        let webView = WKWebView()
        webView.configuration.preferences.javaScriptEnabled = false

        let UA = webView.value(forKey: "userAgent") as? String?
        if let agent = UA {
            request.setValue(appName + "/" + appVersion + " " + agent!, forHTTPHeaderField: userAgentHeader)
        } else {
            request.setValue(appName + "/" + appVersion, forHTTPHeaderField: userAgentHeader)
        }
        
        socket = WebSocket(request: request)
    }

    func connect() {
        socket.delegate = self
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }
    // Sending SDP offer
    func sendOffer(rtcSdp: RTCSessionDescription, senderClientid: String) {
        do {
            if self.isPrintDebugData {
                debugPrint("Sending SDP offer::: \(rtcSdp)")
            } else {
                debugPrint("Sending SDP offer")
            }
            let message: Message = Message.createOfferMessage(sdp: rtcSdp.sdp, senderClientId: senderClientid)
            let data = try encoder.encode(message)
            let msg = String(data: data, encoding: .utf8)!
            socket.write(string: msg)
            
            if self.isPrintDebugData {
                print("Sent SDP offer message over to signaling::: ", msg)
            } else {
                print("Sent SDP offer message over to signaling")
            }
        } catch {
            if self.isPrintDebugData {
                print("send offer error::: ",error)
            } else {
                print("send offer error")
            }
        }
    }
    // Sending SDP Answer
    func sendAnswer(rtcSdp: RTCSessionDescription, recipientClientId: String) {
        do {
            if self.isPrintDebugData {
                debugPrint("Sending SDP answer::: \(rtcSdp)")
            } else {
                debugPrint("Sending SDP answer")
            }
            let message: Message = Message.createAnswerMessage(sdp: rtcSdp.sdp, recipientClientId)
            let data = try encoder.encode(message)
            let msg = String(data: data, encoding: .utf8)!
            socket.write(string: msg)
            if self.isPrintDebugData {
                print("Sent SDP answer message over to signaling::: ", msg)
            } else {
                print("Sent SDP answer message over to signaling")
            }
        } catch {
            if self.isPrintDebugData {
                print("send asnswer error::: ",error)
            } else {
                print("send asnswer error")
            }
        }
    }
    
    // Pass Data :- Like sample_rate, bit_depth
    func sendMessage(message: String) {
        socket.write(string: message)
        if self.isPrintDebugData {
            print("paas data::: ", message)
        } else {
            print("paas data")
        }
    }
    
    func sendIceCandidate(rtcIceCandidate: RTCIceCandidate, master: Bool,
                          recipientClientId: String,
                          senderClientId: String) {
        do {
            if self.isPrintDebugData {
                debugPrint("Sending ICE candidate::: \(rtcIceCandidate)")
            } else {
                debugPrint("Sending ICE candidate")
            }
            let message: Message = Message.createIceCandidateMessage(candidate: rtcIceCandidate,
                                                                     master,
                                                                     recipientClientId: recipientClientId,
                                                                     senderClientId: senderClientId)
            let data = try encoder.encode(message)
            let msg = String(data: data, encoding: .utf8)!
            socket.write(string: msg)
            if self.isPrintDebugData {
                print("Sent ICE candidate message over to signaling::: ", msg)
            } else {
                print("Sent ICE candidate message over to signaling:")
            }
        } catch {
            if self.isPrintDebugData {
                print("send ICE canndidate error:::",error)
            } else {
                print("send ICE canndidate error")
            }
        }
    }
}

// MARK: Websocket Delegate
extension SignalingClient: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            delegate?.signalClientDidConnect(self)
            if self.isPrintDebugData {
                debugPrint("Connection to signaling success. Headers::: \(headers)")
            } else {
                debugPrint("Connection to signaling success. Headers")
            }

        case .disconnected(let reason, let code):
            delegate?.signalClientDidDisconnect(self)
            if self.isPrintDebugData {
                debugPrint("Disconnected from signaling. Reason::: \(reason), Code::: \(code)")
            } else {
                debugPrint("Disconnected from signaling. Reason:, Code: ")
            }

        case .text(let text):
            guard !text.isEmpty, let parsedMessage = Event.parseEvent(event: text) else {
                return
            }

            let messagePayload = parsedMessage.getMessagePayload()
            let messageType = parsedMessage.getAction()
            let senderClientId = parsedMessage.getSenderClientId()

            guard let messagePayloadDecoded = messagePayload.base64Decoded() else {
                debugPrint("Failed to decode message payload")
                return
            }
            
            do {
                var jsonObject = [String:Any]()
                if let decodedJSON = decodeJSONString(jsonString: messagePayloadDecoded) {
                    jsonObject = decodedJSON
                } else {
                    print("Failed to decode JSON string")
                }

                switch messageType {
                case "SDP_OFFER":
                    if let sdp = jsonObject["sdp"] as? String {
                        let rcSessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
                        delegate?.signalClient(self, senderClientId: senderClientId, didReceiveRemoteSdp: rcSessionDescription)
                        
                        if self.isPrintDebugData {
                            debugPrint("SDP offer received from signaling::: \(sdp)")
                        } else {
                            debugPrint("SDP offer received from signaling")
                        }
                    }
                case "SDP_ANSWER":
                    if let sdp = jsonObject["sdp"] as? String {
                        let rcSessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
                        delegate?.signalClient(self, senderClientId: senderClientId, didReceiveRemoteSdp: rcSessionDescription)
                        
                        if self.isPrintDebugData {
                            debugPrint("SDP answer received from signaling::: \(sdp)")
                        } else {
                            debugPrint("SDP answer received from signaling")
                        }
                    }
                case "ICE_CANDIDATE":
                    if let iceCandidate = jsonObject["candidate"] as? String,
                       let sdpMid = jsonObject["sdpMid"] as? String,
                       let sdpMLineIndex = jsonObject["sdpMLineIndex"] as? Int32 {
                        let rtcIceCandidate = RTCIceCandidate(sdp: iceCandidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                        delegate?.signalClient(self, senderClientId: senderClientId, didReceiveCandidate: rtcIceCandidate)
                        
                        if self.isPrintDebugData {
                            debugPrint("ICE candidate received from signaling::: \(iceCandidate)")
                        } else {
                            debugPrint("ICE candidate received from signaling")
                        }
                    }
                default:
                    break
                }
            } catch {
                
                if self.isPrintDebugData {
                    debugPrint("Payload parsing error::: \(error)")
                } else {
                    debugPrint("Payload parsing error")
                }
            }
            
        case .binary(let data):
            
            if self.isPrintDebugData {
                debugPrint("Additional signaling data (not supported)::: \(data)")
            } else {
                debugPrint("Additional signaling data (not supported)")
            }
            
        case .cancelled:
            debugPrint("Connection cancelled")
            
        case .peerClosed :
            debugPrint("peerClosed")
            
        case .error(let error):
            
            if self.isPrintDebugData {
                debugPrint("Connection error::: \(error?.localizedDescription ?? "Unknown error")")
            } else {
                debugPrint("Connection error")
            }
            
        default:
            break
        }
    }
    
    
    
    func decodeJSONString(jsonString: String) -> [String: Any]? {
        // Step 1: Replace escaped backslashes with actual backslashes
        var cleanJSONString = jsonString.replacingOccurrences(of: "\\\\", with: "\\")
        
        // Step 2: Replace escaped double quotes with actual double quotes
        cleanJSONString = cleanJSONString.replacingOccurrences(of: "\\\"", with: "\"")
        
        // Step 3: Remove enclosing quotes if present
        cleanJSONString = cleanJSONString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
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
    func websocketDidConnect(socket _: WebSocketClient) {
        delegate?.signalClientDidConnect(self)
        debugPrint("Connection to signaling success.")
    }

    func websocketDidDisconnect(socket _: WebSocketClient, error: Error?) {
        delegate?.signalClientDidDisconnect(self)
        
        if self.isPrintDebugData {
            debugPrint("Disconnected from signaling::: \(error != nil ? error!.localizedDescription : "")")
        } else {
            debugPrint("Disconnected from signaling")
        }
    }

    func websocketDidReceiveData(socket _: WebSocketClient, data: Data) {
        
        if self.isPrintDebugData {
            debugPrint("Additional signaling data (not supported)::: \(data)")
        } else {
            debugPrint("Additional signaling data (not supported)")
        }
    }

    func websocketDidReceiveMessage(socket _: WebSocketClient, text: String) {
        debugPrint("Additional signaling messages \(text)")
        var parsedMessage: Message?
        
        if text != "" {
            parsedMessage = Event.parseEvent(event: text)
        }
        
        if parsedMessage != nil {
            let messagePayload = parsedMessage?.getMessagePayload()
            
            let messageType = parsedMessage?.getAction()
            let senderClientId = parsedMessage?.getSenderClientId()
            // todo: add a guard here because some of java base64 encode options might break ios base64 decode unless extended
            let message: String = String(messagePayload!.base64Decoded()!)
            
            do {
                let jsonObject = try message.trim().convertToDictionary()
                if jsonObject.count != 0 {
                    if messageType == "SDP_OFFER" {
                        guard let sdp = jsonObject["sdp"] as? String else {
                            return
                        }
                        let rcSessionDescription: RTCSessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
                        delegate?.signalClient(self, senderClientId: senderClientId!, didReceiveRemoteSdp: rcSessionDescription)
                        
                        if self.isPrintDebugData {
                            debugPrint("SDP offer received from signaling::: \(sdp)")
                        } else {
                            debugPrint("SDP offer received from signaling")
                        }
                    } else if messageType == "SDP_ANSWER" {
                        guard let sdp = jsonObject["sdp"] as? String else {
                            return
                        }
                        let rcSessionDescription: RTCSessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
                        delegate?.signalClient(self, senderClientId: "", didReceiveRemoteSdp: rcSessionDescription)
                        
                        if self.isPrintDebugData {
                            debugPrint("SDP answer received from signaling::: \(sdp)")
                        } else {
                            debugPrint("SDP answer received from signaling")
                        }
                    } else if messageType == "ICE_CANDIDATE" {
                        guard let iceCandidate = jsonObject["candidate"] as? String else {
                            return
                        }
                        guard let sdpMid = jsonObject["sdpMid"] as? String else {
                            return
                        }
                        guard let sdpMLineIndex = jsonObject["sdpMLineIndex"] as? Int32 else {
                            return
                        }
                        let rtcIceCandidate: RTCIceCandidate = RTCIceCandidate(sdp: iceCandidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                        delegate?.signalClient(self, senderClientId: senderClientId!, didReceiveCandidate: rtcIceCandidate)
                        
                        if self.isPrintDebugData {
                            debugPrint("ICE candidate received from signaling::: \(iceCandidate)")
                        } else {
                            debugPrint("ICE candidate received from signaling")
                        }
                    }
                } else {
                    dump(jsonObject)
                }
            } catch {
                
                if self.isPrintDebugData {
                    print("payLoad parsing Error::: \(error)")
                } else {
                    print("payLoad parsing Error")
                }
            }
        }
    }
}

extension String {
    func trim() -> String {
        return trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
    
    func convertToDictionary() throws -> [String: Any] {
        let data = Data(utf8)

        if let anyResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return anyResult
        } else {
            return [:]
        }
    }
}
