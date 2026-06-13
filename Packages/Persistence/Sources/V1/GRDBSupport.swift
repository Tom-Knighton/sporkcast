//
//  GRDBSupport.swift
//  Persistence
//
//  Created by Tom Knighton on 10/06/2026.
//

@_exported import Dependencies
import Foundation
@_exported import GRDB

public typealias Configuration = GRDB.Configuration

public func defaultDatabase(
    path: String? = nil,
    configuration: Configuration = Configuration()
) throws -> any DatabaseWriter {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return try DatabaseQueue(configuration: configuration)
    }

    let databasePath: String
    if let path {
        databasePath = path
    } else {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let databaseURL = applicationSupportDirectory.appendingPathComponent("Sporkcast.sqlite")
        try migrateLegacyDatabaseFile(to: databaseURL, in: applicationSupportDirectory)
        databasePath = databaseURL.path
    }

    return try DatabasePool(path: databasePath, configuration: configuration)
}

private func migrateLegacyDatabaseFile(to databaseURL: URL, in directory: URL) throws {
    let legacyURL = directory.appendingPathComponent("SQLiteData.db")
    let fileManager = FileManager.default

    guard !fileManager.fileExists(atPath: databaseURL.path),
          fileManager.fileExists(atPath: legacyURL.path)
    else { return }

    try fileManager.copyItem(at: legacyURL, to: databaseURL)

    for suffix in ["-wal", "-shm"] {
        let legacySidecar = URL(fileURLWithPath: legacyURL.path + suffix)
        let sidecar = URL(fileURLWithPath: databaseURL.path + suffix)
        if fileManager.fileExists(atPath: legacySidecar.path),
           !fileManager.fileExists(atPath: sidecar.path) {
            try fileManager.copyItem(at: legacySidecar, to: sidecar)
        }
    }
}

public extension DependencyValues {
    var defaultDatabase: any DatabaseWriter {
        get { self[DefaultDatabaseKey.self] }
        set { self[DefaultDatabaseKey.self] = newValue }
    }
}

private enum DefaultDatabaseKey: DependencyKey {
    static var liveValue: any DatabaseWriter { testValue }

    static var testValue: any DatabaseWriter {
        do {
            return try DatabaseQueue()
        } catch {
            fatalError("Unable to create fallback database: \(error)")
        }
    }
}

public protocol DBRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Identifiable, Equatable, Sendable where ID == UUID {
    static var idColumnName: String { get }
}

public extension DBRecord {
    static var idColumnName: String { "id" }
    static var all: DBQuery<Self> { DBQuery(tableName: databaseTableName) }

    static func find(_ id: UUID) -> DBQuery<Self> {
        DBQuery(tableName: databaseTableName).where(SQLCondition(column: idColumnName, op: "=", value: id))
    }

    static func `where`(_ predicate: (DBColumns) -> SQLCondition) -> DBQuery<Self> {
        all.where(predicate(DBColumns()))
    }

    static func `where`(_ condition: SQLCondition) -> DBQuery<Self> {
        all.where(condition)
    }

    static func insert(_ build: () -> Self) -> DBInsertCommand<Self> {
        DBInsertCommand(rows: [build()], replace: false)
    }

    static func insert(_ build: () -> [Self]) -> DBInsertCommand<Self> {
        DBInsertCommand(rows: build(), replace: false)
    }

    static func upsert(_ build: () -> Self) -> DBInsertCommand<Self> {
        DBInsertCommand(rows: [build()], replace: true)
    }

    static func upsert(_ build: () -> [Self]) -> DBInsertCommand<Self> {
        DBInsertCommand(rows: build(), replace: true)
    }

    static func delete() -> DBDeleteCommand<Self> {
        DBDeleteCommand(query: all)
    }

    static func order<Value: Comparable>(by keyPath: KeyPath<Self, Value>) -> DBQuery<Self> {
        all.order(by: keyPath)
    }
}

@dynamicMemberLookup
public struct DBColumns: Sendable {
    public subscript(dynamicMember member: String) -> DBColumn {
        DBColumn(name: member)
    }
}

public struct DBColumn: Sendable {
    public let name: String

    public func eq(_ value: (any DatabaseValueConvertible)?) -> SQLCondition {
        SQLCondition(column: name, op: "=", value: value)
    }

    public func `is`(_ value: Any?) -> SQLCondition {
        if value == nil {
            SQLCondition(sql: "\(name) IS NULL", arguments: [])
        } else {
            SQLCondition(column: name, op: "IS", value: value as? any DatabaseValueConvertible)
        }
    }

    public func isNot(_ value: Any?) -> SQLCondition {
        if value == nil {
            SQLCondition(sql: "\(name) IS NOT NULL", arguments: [])
        } else {
            SQLCondition(column: name, op: "IS NOT", value: value as? any DatabaseValueConvertible)
        }
    }
}

public struct SQLCondition: Sendable {
    public let sql: String
    public let arguments: StatementArguments

    public init(sql: String, arguments: StatementArguments = []) {
        self.sql = sql
        self.arguments = arguments
    }

    public init(column: String, op: String, value: (any DatabaseValueConvertible)?) {
        if let value {
            self.sql = "\(column) \(op) ?"
            self.arguments = [value.databaseValue]
        } else {
            self.sql = "\(column) IS NULL"
            self.arguments = []
        }
    }
}

public func && (lhs: SQLCondition, rhs: SQLCondition) -> SQLCondition {
    var arguments = lhs.arguments
    arguments += rhs.arguments
    return SQLCondition(sql: "(\(lhs.sql)) AND (\(rhs.sql))", arguments: arguments)
}

public func || (lhs: SQLCondition, rhs: SQLCondition) -> SQLCondition {
    var arguments = lhs.arguments
    arguments += rhs.arguments
    return SQLCondition(sql: "(\(lhs.sql)) OR (\(rhs.sql))", arguments: arguments)
}

public prefix func ! (condition: SQLCondition) -> SQLCondition {
    SQLCondition(sql: "NOT (\(condition.sql))", arguments: condition.arguments)
}

public func >= (lhs: DBColumn, rhs: any DatabaseValueConvertible) -> SQLCondition {
    SQLCondition(column: lhs.name, op: ">=", value: rhs)
}

public func <= (lhs: DBColumn, rhs: any DatabaseValueConvertible) -> SQLCondition {
    SQLCondition(column: lhs.name, op: "<=", value: rhs)
}

public extension Set where Element: DatabaseValueConvertible {
    func contains(_ column: DBColumn) -> SQLCondition {
        guard !isEmpty else { return SQLCondition(sql: "0", arguments: []) }
        let placeholders = Swift.Array(repeating: "?", count: count).joined(separator: ", ")
        return SQLCondition(
            sql: "\(column.name) IN (\(placeholders))",
            arguments: StatementArguments(map(\.databaseValue))
        )
    }
}

public extension Array where Element: DatabaseValueConvertible {
    func contains(_ column: DBColumn) -> SQLCondition {
        guard !isEmpty else { return SQLCondition(sql: "0", arguments: []) }
        let placeholders = Swift.Array(repeating: "?", count: count).joined(separator: ", ")
        return SQLCondition(
            sql: "\(column.name) IN (\(placeholders))",
            arguments: StatementArguments(map(\.databaseValue))
        )
    }
}

public struct DBQuery<Row: FetchableRecord & Sendable>: @unchecked Sendable {
    public let tableName: String?
    public var condition: SQLCondition?
    public var limitCount: Int?
    public var sorter: ((Row, Row) -> Bool)?
    public var fetcher: ((Database, DBQuery<Row>) throws -> [Row])?

    public init(tableName: String? = nil) {
        self.tableName = tableName
    }

    public init(fetcher: @escaping (Database, DBQuery<Row>) throws -> [Row]) {
        self.tableName = nil
        self.fetcher = fetcher
    }

    public func `where`(_ condition: SQLCondition) -> DBQuery<Row> {
        var copy = self
        if let existing = copy.condition {
            copy.condition = existing && condition
        } else {
            copy.condition = condition
        }
        return copy
    }

    public func `where`(_ predicate: (DBColumns) -> SQLCondition) -> DBQuery<Row> {
        self.where(predicate(DBColumns()))
    }

    public func find(_ id: UUID) -> DBQuery<Row> {
        self.where(SQLCondition(column: "id", op: "=", value: id))
    }

    public func order<Value: Comparable>(by keyPath: KeyPath<Row, Value>) -> DBQuery<Row> {
        var copy = self
        copy.sorter = { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
        return copy
    }

    public func limit(_ count: Int) -> DBQuery<Row> {
        var copy = self
        copy.limitCount = count
        return copy
    }

    public func select<Value>(_ keyPath: KeyPath<Row, Value>) -> DBSelectQuery<Row, Value> {
        DBSelectQuery(query: self, keyPath: keyPath)
    }

    public func delete() -> DBDeleteCommand<Row> {
        DBDeleteCommand(query: self)
    }

    public func fetchAll(_ db: Database) throws -> [Row] {
        var rows: [Row]
        if let fetcher {
            rows = try fetcher(db, self)
        } else {
            guard let tableName else { return [] }
            var sql = "SELECT * FROM \(tableName)"
            var arguments: StatementArguments = []
            if let condition {
                sql += " WHERE \(condition.sql)"
                arguments = condition.arguments
            }
            rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        }
        if let sorter {
            rows.sort(by: sorter)
        }
        if let limitCount, rows.count > limitCount {
            rows = Array(rows.prefix(limitCount))
        }
        return rows
    }

    public func fetchOne(_ db: Database) throws -> Row? {
        try limit(1).fetchAll(db).first
    }
}

public extension DBQuery where Row: MutablePersistableRecord {
    func update(_ mutate: @escaping (inout Row) -> Void) -> DBUpdateCommand<Row> {
        DBUpdateCommand(query: self, mutate: mutate)
    }
}

public struct DBSelectQuery<Row: FetchableRecord & Sendable, Value> {
    let query: DBQuery<Row>
    let keyPath: KeyPath<Row, Value>

    public func fetchAll(_ db: Database) throws -> [Value] {
        try query.fetchAll(db).map { $0[keyPath: keyPath] }
    }
}

public struct DBInsertCommand<Row: DBRecord> {
    let rows: [Row]
    let replace: Bool

    public func execute(_ db: Database) throws {
        for row in rows {
            var copy = row
            if replace {
                try copy.upsert(db)
            } else {
                try copy.insert(db)
            }
        }
    }
}

public struct DBDeleteCommand<Row: FetchableRecord & Sendable> {
    let query: DBQuery<Row>

    public func execute(_ db: Database) throws {
        guard let tableName = query.tableName else {
            for row in try query.fetchAll(db) {
                guard let record = row as? any DBRecord else { continue }
                try db.execute(
                    sql: "DELETE FROM \(type(of: record).databaseTableName) WHERE \(type(of: record).idColumnName) = ?",
                    arguments: [record.id]
                )
            }
            return
        }

        var sql = "DELETE FROM \(tableName)"
        var arguments: StatementArguments = []
        if let condition = query.condition {
            sql += " WHERE \(condition.sql)"
            arguments = condition.arguments
        }
        try db.execute(sql: sql, arguments: arguments)
    }
}

public struct DBUpdateCommand<Row: FetchableRecord & MutablePersistableRecord & Sendable> {
    let query: DBQuery<Row>
    let mutate: (inout Row) -> Void

    public func execute(_ db: Database) throws {
        var rows = try query.fetchAll(db)
        for index in rows.indices {
            mutate(&rows[index])
            try rows[index].update(db)
        }
    }
}

@MainActor
public func observeAll<Row: Equatable & Sendable>(
    _ database: any DatabaseReader,
    query: DBQuery<Row>,
    onError: @escaping @MainActor (Error) -> Void = { _ in },
    onChange: @escaping @MainActor ([Row]) -> Void
) -> AnyDatabaseCancellable where Row: FetchableRecord {
    ValueObservation
        .tracking { db in try query.fetchAll(db) }
        .removeDuplicates()
        .start(in: database, scheduling: .immediate, onError: onError, onChange: onChange)
}

@MainActor
public func observeOne<Row: Equatable & Sendable>(
    _ database: any DatabaseReader,
    query: DBQuery<Row>,
    onError: @escaping @MainActor (Error) -> Void = { _ in },
    onChange: @escaping @MainActor (Row?) -> Void
) -> AnyDatabaseCancellable where Row: FetchableRecord {
    ValueObservation
        .tracking { db in try query.fetchOne(db) }
        .removeDuplicates()
        .start(in: database, scheduling: .immediate, onError: onError, onChange: onChange)
}
