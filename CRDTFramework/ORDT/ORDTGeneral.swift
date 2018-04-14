//
//  ORDTGeneral.swift
//  CRDTPlayground
//
//  Created by Alexei Baboulevitch on 2018-4-10.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

import Foundation

public protocol OperationType
{
    associatedtype ValueT
    
    var id: AtomId { get }
    var timestamp: YarnIndex { get } //TODO: rename, use Clock, put in AtomId
    var value: ValueT { get }
}

public protocol CausalOperationType: OperationType
{
    var cause: AtomId { get }
}

/// A self-contained ORDT data structure.
public protocol ORDT: CvRDT, ApproxSizeable, IndexRemappable
{
    associatedtype OperationT: OperationType
    associatedtype CollectionT: RandomAccessCollection where CollectionT.Element == OperationT
    
    var lamportClock: Clock { get }
    
    /// Produces every operation in the ORDT in the "appropriate" order, i.e. optimal for queries and reconstruction
    /// of the object. Not necessarily a cheap call: *O*(*n*) if the ORDT stores its operations in an array, but
    /// potentially higher if custom internal data structures are involved, or if the collection needs to be generated first.
    func operations(withWeft: Weft<SiteId>?) -> CollectionT
    
    /// Produces every operation for a given site in the sequence of their creation. Not necessarily a cheap call:
    /// *O*(*n*) if the ORDT caches its yarns, but potentially higher if custom internal data structures are involved,
    /// or if the collection needs to be generated first.
    func yarn(forSite: SiteId, withWeft: Weft<SiteId>?) -> CollectionT
    
    /// Presents a historic version of the data structure. Copy-on-write, should be treated as read-only.
    func revision(_ weft: Weft<SiteId>?) -> Self
    
    /// Throws SetBaselineError. An ORDT is not required to implement baselining.
    mutating func setBaseline(_ weft: Weft<SiteId>) throws
    
    var baseline: Weft<SiteId>? { get }
    
    /// The full weft of the current state of the ORDT.
    var indexWeft: Weft<SiteId> { get }
    //var lamportWeft: Weft { get }
}

extension ORDT
{
    // Potentially very expensive if `operations` requires sorting or cache generation.
    public func sizeInBytes() -> Int
    {
        return Int(operations(withWeft: nil).count) * MemoryLayout<OperationT>.size
    }
}
extension ORDT
{
    /// An "eager" garbage collector that simply sets the baseline to the current weft. Only recommended for
    /// cases where the baseline does not need to be replicated, and/or when the baseline only removes operations
    /// (as in an LWW ORDT).
    public mutating func garbageCollect() throws
    {
        try setBaseline(self.indexWeft)
    }
}

/// An ORDT in which each comprising ORDT uses a single, global Lamport timestamp.
public protocol UsesGlobalLamport
{
    weak var lamportDelegate: ORDTGlobalLamportDelegate? { get set }
}

/// An ORDT in which site IDs need to be mapped to and from UUIDs.
public protocol UsesSiteMapping
{
    weak var siteMappingDelegate: ORDTSiteMappingDelegate? { get set }
}

public protocol ORDTSiteMappingDelegate: class
{
    func LUIDForUUID(_ luid: SiteId)
    func UUIDForLUID(_ uuid: UUID)
}

public protocol ORDTGlobalLamportDelegate: class
{
    var delegateLamportClock: Int { get }
}

// TODO: maybe CvRDTContainer with a contraint for T == ORDT?
/// When multiple ORDTs are processed together, baseline and operation commands no longer make sense. Therefore, it's
/// sensible to have a container ORDT that only exposes the methods that make sense in aggregate.
public protocol ORDTContainer: CvRDT, ApproxSizeable, IndexRemappable
{
    var lamportClock: Clock { get }
    
    //func revision(_ weft: Int?) -> Self
    
    //var lamportWeft: Weft { get }
}

/// Errors when garbage collecting and setting the baseline.
enum SetBaselineError: Error
{
    case notSupported
    case causallyInconsistent
    case internallyInconsistent
}

public enum ValidationError: Error
{
    case incorrectOperationOrder
    case inconsistentWeft
    case inconsistentLamportTimestamp
    case inconsistentCaches
}