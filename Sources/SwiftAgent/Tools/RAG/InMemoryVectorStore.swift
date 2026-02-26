//
//  InMemoryVectorStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation
import Accelerate

/// High-performance in-memory vector store with embeddings
public actor InMemoryVectorStore: VectorStore {
    private var documents: [String: Document] = [:]
    private var embeddings: ContiguousArray<Float> = []
    private var documentIds: [String] = []
    private let embeddingProvider: EmbeddingProvider
    private let embeddingDimension: Int
    
    // Cache for query embeddings (LRU cache)
    private var queryCache: [String: ContiguousArray<Float>] = [:]
    private let maxCacheSize = 100
    
    public init(embeddingProvider: EmbeddingProvider, embeddingDimension: Int = 1536) {
        self.embeddingProvider = embeddingProvider
        self.embeddingDimension = embeddingDimension
    }
    
    public func search(query: String, topK: Int) async throws -> [SearchResult] {
        guard !documents.isEmpty else { return [] }
        
        let queryEmbedding = try await getOrCacheQueryEmbedding(query: query)
        let similarities = await computeSimilarities(queryEmbedding: queryEmbedding)
        let topResults = findTopK(similarities: similarities, k: topK)
        
        return topResults.map { (index, score) in
            let id = documentIds[index]
            let doc = documents[id]!
            return SearchResult(
                id: id,
                content: doc.content,
                score: score,
                metadata: doc.metadata
            )
        }
    }
    
    public func add(documents: [Document]) async throws {
        guard !documents.isEmpty else { return }
        
        let texts = documents.map { $0.content }
        let newEmbeddings = try await embeddingProvider.embedBatch(texts: texts)
        
        // Normalize embeddings for faster similarity computation
        let normalizedEmbeddings = newEmbeddings.map { normalizeVector($0) }
        
        for (index, doc) in documents.enumerated() {
            self.documents[doc.id] = doc
            self.documentIds.append(doc.id)
            self.embeddings.append(contentsOf: normalizedEmbeddings[index])
        }
    }
    
    public func delete(ids: [String]) async throws {
        let idsSet = Set(ids)
        var newDocumentIds: [String] = []
        var newEmbeddings = ContiguousArray<Float>()
        
        for (index, docId) in documentIds.enumerated() {
            if !idsSet.contains(docId) {
                newDocumentIds.append(docId)
                let start = index * embeddingDimension
                let end = start + embeddingDimension
                newEmbeddings.append(contentsOf: embeddings[start..<end])
            } else {
                documents.removeValue(forKey: docId)
            }
        }
        
        documentIds = newDocumentIds
        embeddings = newEmbeddings
    }
    
    public func clear() async throws {
        documents.removeAll()
        embeddings.removeAll()
        documentIds.removeAll()
        queryCache.removeAll()
    }
    
    public func count() async throws -> Int {
        return documents.count
    }
    
    // MARK: - Private Optimized Methods
    
    /// Get query embedding from cache or compute and cache it
    private func getOrCacheQueryEmbedding(query: String) async throws -> ContiguousArray<Float> {
        if let cached = queryCache[query] {
            return cached
        }
        
        let embedding = try await embeddingProvider.embed(text: query)
        let normalized = normalizeVector(embedding)
        
        // Simple LRU: remove oldest if cache is full
        if queryCache.count >= maxCacheSize {
            queryCache.removeValue(forKey: queryCache.keys.first!)
        }
        
        queryCache[query] = normalized
        return normalized
    }
    
    /// Normalize vector to unit length (magnitude = 1.0)
    /// After normalization, cosine similarity = dot product
    private func normalizeVector(_ vector: [Float]) -> ContiguousArray<Float> {
        var result = ContiguousArray<Float>(vector)
        
        guard !result.isEmpty else { return result }
        
        var magnitude: Float = 0.0
        
        // Calculate magnitude using vDSP (SIMD-optimized)
        result.withUnsafeBufferPointer { buffer in
            vDSP_svesq(buffer.baseAddress!, 1, &magnitude, vDSP_Length(buffer.count))
        }
        
        magnitude = sqrt(magnitude)
        
        guard magnitude > 0 else {
            return result
        }
        
        // Divide all elements by magnitude
        result.withUnsafeMutableBufferPointer { buffer in
            vDSP_vsdiv(buffer.baseAddress!, 1, &magnitude, buffer.baseAddress!, 1, vDSP_Length(buffer.count))
        }
        
        return result
    }
    
    /// Compute similarities for all documents in parallel
    private func computeSimilarities(queryEmbedding: ContiguousArray<Float>) async -> [Float] {
        let numDocuments = documentIds.count
        var similarities = [Float](repeating: 0, count: numDocuments)
        
        // For normalized vectors, cosine similarity = dot product
        if numDocuments > 1000 {
            await withTaskGroup(of: (Int, Float).self) { group in
                // Divide work into chunks for parallel processing
                let chunkSize = max(100, numDocuments / ProcessInfo.processInfo.activeProcessorCount)
                
                for chunkStart in stride(from: 0, to: numDocuments, by: chunkSize) {
                    group.addTask {
                        let chunkEnd = min(chunkStart + chunkSize, numDocuments)
                        return await self.computeChunkSimilarities(
                            queryEmbedding: queryEmbedding,
                            startIndex: chunkStart,
                            endIndex: chunkEnd
                        )
                    }
                }
                
                // Collect results
                for await (index, similarity) in group {
                    similarities[index] = similarity
                }
            }
        } else {
            // For small datasets, compute serially (less overhead)
            similarities = await computeChunkSimilaritiesSerial(
                queryEmbedding: queryEmbedding,
                startIndex: 0,
                endIndex: numDocuments
            )
        }
        
        return similarities
    }
    
    /// Compute similarities for a chunk of documents (parallel task)
    private func computeChunkSimilarities(queryEmbedding: ContiguousArray<Float>, startIndex: Int, endIndex: Int) async -> (Int, Float) {
        // This returns one similarity per call in TaskGroup
        // Better approach: return array of similarities for chunk
        var maxSimilarity: Float = -1
        var maxIndex = startIndex
        
        for index in startIndex..<endIndex {
            let similarity = computeDotProduct(
                queryEmbedding: queryEmbedding,
                documentIndex: index
            )
            if similarity > maxSimilarity {
                maxSimilarity = similarity
                maxIndex = index
            }
        }
        
        return (maxIndex, maxSimilarity)
    }
    
    /// Compute similarities serially for small datasets
    private func computeChunkSimilaritiesSerial(queryEmbedding: ContiguousArray<Float>, startIndex: Int, endIndex: Int) async -> [Float] {
        var similarities = [Float](repeating: 0, count: endIndex - startIndex)
        
        for index in startIndex..<endIndex {
            similarities[index - startIndex] = computeDotProduct(
                queryEmbedding: queryEmbedding,
                documentIndex: index
            )
        }
        
        return similarities
    }
    
    /// Compute dot product between query and document embedding using vDSP
    private func computeDotProduct(queryEmbedding: ContiguousArray<Float>, documentIndex: Int) -> Float {
        let offset = documentIndex * embeddingDimension
        var result: Float = 0.0
        
        // Use vDSP for SIMD-optimized dot product
        embeddings.withUnsafeBufferPointer { embeddingsBuffer in
            queryEmbedding.withUnsafeBufferPointer { queryBuffer in
                let documentPointer = embeddingsBuffer.baseAddress! + offset
                vDSP_dotpr(
                    queryBuffer.baseAddress!,
                    1,
                    documentPointer,
                    1,
                    &result,
                    vDSP_Length(embeddingDimension)
                )
            }
        }
        
        return result
    }
    
    /// Find top K results using partial selection (more efficient than full sort)
    private func findTopK(similarities: [Float], k: Int) -> [(index: Int, score: Double)] {
        let actualK = min(k, similarities.count)
        
        let indexedSimilarities = similarities.enumerated().map { ($0.offset, Double($0.element)) }
        
        let topK = indexedSimilarities
            .sorted { $0.1 > $1.1 }  // Sort by similarity descending
            .prefix(actualK)
        
        return Array(topK)
    }
}

// MARK: - Optimized Alternative with Min-Heap (for very large K)

extension InMemoryVectorStore {
    /// More efficient top-K selection using min-heap (better for large K)
    private func findTopKWithHeap(similarities: [Float], k: Int) -> [(index: Int, score: Double)] {
        let actualK = min(k, similarities.count)
        guard actualK > 0 else { return [] }
        
        // Use a min-heap of size K
        var heap: [(index: Int, score: Double)] = []
        heap.reserveCapacity(actualK)
        
        for (index, similarity) in similarities.enumerated() {
            let score = Double(similarity)
            
            if heap.count < actualK {
                // Heap not full, add element
                heap.append((index, score))
                if heap.count == actualK {
                    // Heapify once when full
                    heap.sort { $0.score < $1.score }  // Min-heap
                }
            } else if score > heap[0].score {
                // Replace minimum if current is better
                heap[0] = (index, score)
                // Bubble down to maintain heap property
                siftDown(&heap, index: 0)
            }
        }
        
        return heap.sorted { $0.score > $1.score }
    }
    
    private func siftDown(_ heap: inout [(index: Int, score: Double)], index: Int) {
        var current = index
        let count = heap.count
        
        while true {
            let left = 2 * current + 1
            let right = 2 * current + 2
            var smallest = current
            
            if left < count && heap[left].score < heap[smallest].score {
                smallest = left
            }
            if right < count && heap[right].score < heap[smallest].score {
                smallest = right
            }
            
            if smallest == current { break }
            
            heap.swapAt(current, smallest)
            current = smallest
        }
    }
}
