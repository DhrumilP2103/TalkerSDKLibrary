//
//  Lib.swift
//  BuildYaar
//
//  Created by Kiran Jamod on 01/08/23.
//

import Foundation

public func checkInternet() ->Bool
{
    let status = LetsReach().connectionStatus()
    switch status {
    case .unknown, .offline:
        return false
    case .online(.wwan), .online(.wiFi):
        return true
    }
    
}

func DEBUGLOG(_ value:Any){
    print(value)
}

func DEBUGAPI(_ value:Any){
    print(value)
}
