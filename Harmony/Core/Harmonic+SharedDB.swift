import GRDB
import Foundation

extension Harmonic {
  
  /// Returns an initialized database pool at the shared location databasePath
  static func openSharedDatabase(at databasePath: String) throws -> DatabasePool {
      let coordinator = NSFileCoordinator(filePresenter: nil)
      var coordinatorError: NSError?
      var dbPool: DatabasePool?
      var dbError: Error?
      coordinator.coordinate(writingItemAt: databasePath, options: .forMerging, error: &coordinatorError) { url in
          do {
              dbPool = try openDatabase(at: url)
          } catch {
              dbError = error
          }
      }
      if let error = dbError ?? coordinatorError {
          throw error
      }
      return dbPool!
  }


  private static func openDatabase(at databasePath: String) throws -> DatabasePool {
      var configuration = Configuration()
      configuration.prepareDatabase { db in
          // Activate the persistent WAL mode so that
          // read-only processes can access the database.
          //
          // See https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use
          // and https://www.sqlite.org/c3ref/c_fcntl_begin_atomic_write.html#sqlitefcntlpersistwal
          if db.configuration.readonly == false {
              var flag: CInt = 1
              let code = withUnsafeMutablePointer(to: &flag) { flagP in
                  sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
              }
              guard code == SQLITE_OK else {
                  throw DatabaseError(resultCode: ResultCode(rawValue: code))
              }
          }
      }
      let dbPool = try DatabasePool(path: databasePath, configuration: configuration)
      
      return dbPool
  }
}