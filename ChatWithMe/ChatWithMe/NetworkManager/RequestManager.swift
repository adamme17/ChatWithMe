//
//  RequestManager.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 11.05.23.
//

import Foundation

final class RequestManager {
    let network: NetworkManagerProtocol = NetworkManager.shared
}

extension RequestManager {
    func analyze(endPoint: EndPoints, completion: @escaping (Result<SentimentModel, Error>) -> Void) {
        network.makeRequest(endPoint: endPoint, completion: completion)
    }
}
