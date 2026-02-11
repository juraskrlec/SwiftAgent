//
//  DocumentChunker.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Utility for chunking documents into smaller pieces
public struct DocumentChunker {
    
    /// Chunk text by word count with overlap
    public static func chunk(text: String, chunkSize: Int = 500, overlap: Int = 50) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        
        guard !words.isEmpty else { return [] }
        guard words.count > chunkSize else { return [text] }
        
        var chunks: [String] = []
        var currentChunk: [String] = []
        
        for (index, word) in words.enumerated() {
            currentChunk.append(word)
            
            // Create chunk when we reach chunk size or end of text
            if currentChunk.count >= chunkSize || index == words.count - 1 {
                chunks.append(currentChunk.joined(separator: " "))
                
                // Keep last 'overlap' words for next chunk (if not at end)
                if index < words.count - 1 {
                    currentChunk = Array(currentChunk.suffix(overlap))
                } else {
                    currentChunk = []
                }
            }
        }
        
        return chunks
    }
    
    /// Chunk text by character count with overlap
    public static func chunkByCharacters(text: String, chunkSize: Int = 2000, overlap: Int = 200) -> [String] {
        guard !text.isEmpty else { return [] }
        guard text.count > chunkSize else { return [text] }
        
        var chunks: [String] = []
        var startIndex = text.startIndex
        
        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[startIndex..<endIndex])
            chunks.append(chunk)
            
            // Move start index forward, accounting for overlap
            let moveBy = chunkSize - overlap
            guard let newStartIndex = text.index(startIndex, offsetBy: moveBy, limitedBy: text.endIndex) else {
                break
            }
            startIndex = newStartIndex
        }
        
        return chunks
    }
    
    /// Chunk by sentences with approximate target size
    public static func chunkBySentences(text: String, targetChunkSize: Int = 500, overlap: Int = 1) -> [String] {
        // Simple sentence splitting (can be improved with NLP)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !sentences.isEmpty else { return [] }
        
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentLength = 0
        
        for (index, sentence) in sentences.enumerated() {
            let sentenceWords = sentence.split(separator: " ").count
            
            if currentLength + sentenceWords > targetChunkSize && !currentChunk.isEmpty {
                // Save current chunk
                chunks.append(currentChunk.joined(separator: ". ") + ".")
                
                // Start new chunk with overlap
                if overlap > 0 {
                    currentChunk = Array(currentChunk.suffix(overlap))
                    currentLength = currentChunk.reduce(0) { $0 + $1.split(separator: " ").count }
                } else {
                    currentChunk = []
                    currentLength = 0
                }
            }
            
            currentChunk.append(sentence)
            currentLength += sentenceWords
        }
        
        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: ". ") + ".")
        }
        
        return chunks
    }
    
    /// Create documents from chunks with metadata
    public static func createDocuments(from text: String, chunkSize: Int = 500, overlap: Int = 50, sourceMetadata: [String: String] = [:]) -> [Document] {
        let chunks = chunk(text: text, chunkSize: chunkSize, overlap: overlap)
        
        return chunks.enumerated().map { index, chunk in
            var metadata = sourceMetadata
            metadata["chunk_index"] = "\(index)"
            metadata["chunk_count"] = "\(chunks.count)"
            
            return Document(
                id: "\(sourceMetadata["source_id"] ?? "unknown")_chunk_\(index)",
                content: chunk,
                metadata: metadata
            )
        }
    }
}
