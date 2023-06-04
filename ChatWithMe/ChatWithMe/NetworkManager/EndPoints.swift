//
//  EndPoints.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 11.05.23.
//

import Foundation

enum EndPoints {
    case analyze(message: String)
}

extension EndPoints {
    var baseUrl: String {
        switch self {
        case .analyze:
            return "http://adambokun.pythonanywhere.com/analyze"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .analyze:
            return .post
        }
    }
    
    var body: [String: Any] {
        switch self {
        case .analyze(let message):
            return ["message": message]
        }
    }
}
