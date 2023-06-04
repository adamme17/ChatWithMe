//
//  SwiftTfIdf.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 5.05.23.
//

import NaturalLanguage
import Foundation

class TfidfVectorizer {
    var uniqueWords: [String]
    var idfValues: [Double]
    
    init(corpus: [String]) {
        self.uniqueWords = TfidfVectorizer.getUniqueWords(corpus: corpus)
        self.idfValues = TfidfVectorizer.calculateIdf(corpus: corpus, uniqueWords: self.uniqueWords)
    }
    
    static func getUniqueWords(corpus: [String]) -> [String] {
        var uniqueWords = Set<String>()
        for document in corpus {
            let words = document.components(separatedBy: .whitespacesAndNewlines)
            uniqueWords.formUnion(words)
        }
        return Array(uniqueWords)
    }
    
    static func calculateTermFrequency(document: String, word: String) -> Double {
        let words = document.components(separatedBy: .whitespacesAndNewlines)
        let wordCount = words.filter({$0 == word}).count
        let totalWords = words.count
        return Double(wordCount) / Double(totalWords)
    }
    
    static func calculateIdf(corpus: [String], uniqueWords: [String]) -> [Double] {
        var idfValues = [Double]()
        let documentCount = Double(corpus.count)
        for word in uniqueWords {
            let documentFrequency = corpus.filter({$0.contains(word)}).count
            let idf = log((documentCount + 1) / (Double(documentFrequency) + 1)) + 1.0
            idfValues.append(idf)
        }
        return idfValues
    }
    
    func transform(document: String) -> [Double] {
        var tfValues = [Double]()
        let words = document.components(separatedBy: .whitespacesAndNewlines)
        let wordCount = Double(words.count)
        for word in self.uniqueWords {
            let termFrequency = TfidfVectorizer.calculateTermFrequency(document: document, word: word)
            let idfValue = self.idfValues[self.uniqueWords.firstIndex(of: word)!]
            let tfIdfValue = termFrequency * idfValue
            tfValues.append(tfIdfValue)
        }
        return tfValues
    }
    
    func transform(corpus: [String]) -> [[Double]] {
        var tfIdfMatrix = [[Double]]()
        for document in corpus {
            let tfIdfValues = transform(document: document)
            tfIdfMatrix.append(tfIdfValues)
        }
        return tfIdfMatrix
    }
}
