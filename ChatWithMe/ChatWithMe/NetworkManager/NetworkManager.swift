//
//  NetworkManager.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 11.05.23.
//

import Foundation

enum HTTPMethod: String {
    case post = "POST"
}

enum APIError: Error {
    case invalidURL
    case networkError
    case invalidResponse
}

private enum NetworkResponse: String, Error {
    case success
    case failed = "Error"
    case noData = "No data"
    case unableToDecode = "Unable to decode"
}

public class NetworkManager: NetworkManagerProtocol {
    
    static let shared = NetworkManager()
    
    private init() { }
    
    var task: URLSessionTask?
    
    private func request (endPoint: EndPoints, completion: @escaping NetworkRouterCompletion) {
        let session = URLSession.shared
        do {
            guard let request = try buildRequest(endPoint)
            else {
                completion(nil, nil, APIError.invalidURL)
                return
            }

            task = session.dataTask(with: request, completionHandler: { data, response, error in
                completion(data, response, error)
            })

        } catch {
            completion(nil, nil, error)
        }
        task?.resume()
    }
    
    public func cancel () {
        task?.cancel()
    }

    private func buildRequest(_ endPoint: EndPoints) throws -> URLRequest? {

        guard let requestUrl = URL(string: endPoint.baseUrl)
        else { return nil }

        var request = URLRequest(url: requestUrl,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 30.0)

        request.httpMethod = endPoint.httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch endPoint.httpMethod {
        case .post:
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: endPoint.body,
                                                              options: .prettyPrinted)
            } catch (let error) {
                print(error)
                return nil
            }
        }
           
        return request
    }
    
    func makeRequest<T: Codable>(endPoint: EndPoints, completion: @escaping (Result<T, Error>) -> Void) {
        request(endPoint: endPoint) { data, response, error in
            if error != nil {
                completion(.failure(NetworkResponse.failed))
            }
            if let response = response as? HTTPURLResponse {
                switch response.statusCode {
                    case 200...299:
                        guard let responseData = data else {
                            completion(.failure(NetworkResponse.noData))
                            return
                        }
                        do {
                            let apiResponse = try JSONDecoder().decode(T.self, from: responseData)
                            print(response.description)
                            print(response.statusCode)
                            completion(.success(apiResponse))
                        } catch let error {
                            print(error.localizedDescription)
                            completion(.failure(NetworkResponse.unableToDecode))
                        }
                    default:
                    do {
                        let jsonObject = try JSONSerialization.jsonObject(with: data!, options: [])
                        let jsonString = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
                        let string = String(data: jsonString, encoding: .utf8)
                        print(string ?? "")
                    } catch {
                    }
                        print(response.description)
                        print(response.statusCode)
                        completion(.failure(NetworkResponse.failed))
                }
            }
        }
    }
}
