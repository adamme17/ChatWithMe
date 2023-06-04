//
//  NetworkManagerProtocol.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 11.05.23.
//

import Foundation

protocol NetworkManagerProtocol {
    typealias NetworkRouterCompletion = (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void
    func cancel ()
    func makeRequest<T: Codable>(endPoint: EndPoints, completion: @escaping (Result<T, Error>) -> Void)
}
