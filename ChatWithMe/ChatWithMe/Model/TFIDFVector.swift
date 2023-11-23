//
//  TFIDFVector.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 5.05.23.
//

import Foundation
import CoreML

class TFIDFVector {
    var idf = [Double]()
    var vocabulary = [String:Int]()
    var norm : Bool = true
    
    func tokenize(_ message:String) -> [String] {
            let trimmed = message.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"))
            let tokens = trimmed.components(separatedBy: CharacterSet.whitespaces)
            return tokens
    }
    
    func countVector(sentence:String) -> [Int:Int]? {
        var vec = [Int:Int]()
        for word in self.tokenize(sentence) {
            if let pos = self.vocabulary[word] {
                if let i = vec[pos] {
                    vec[pos] = i+1
                } else {
                    vec[pos] = 1
                }
            }
        }
        return vec
    }
    
    func idf(word:String) -> Double {
        if let pos = self.vocabulary[word] {
            return self.idf[pos]
        } else {
            return Double(0.0)
        }
    }


    func tfidf(sentence:String) -> [Int:Double] {
        let cv = countVector(sentence: sentence)
        var vec = [Int:Double]()

        cv?.forEach({ (key, value) in
            let i = self.idf[key]
            print(i)
            let t = Double(value) / Double(cv!.count)
            print(t)
            vec[key] = t * i
        })
        //vec now is TFIDF, but is not normalized
        if self.norm { //L2 Norm
            var sum = vec.compactMap{ $1 }.reduce(0) { $0 + $1*$1 }
            sum = sqrt(sum)

            var n = [Int:Double]()

            vec.forEach({ (key, value) in
                n[key] = value / sum
            })

            return n
        }
        return vec
    }
    func multiarray(vector:[Int:Double]) -> MLMultiArray {
        let array = try! MLMultiArray(shape: [NSNumber(integerLiteral: self.vocabulary.count)], dataType: .double)
        for (key, value) in vector {
            array[key] = NSNumber(floatLiteral: value)
        }
        return array
    }
}
