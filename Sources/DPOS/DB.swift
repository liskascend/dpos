// Created by Sinisa Drpa on 10/26/18.

import Foundation
import SwiftKuery
import SwiftKueryPostgreSQL
import Then

let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("lisk"), .userName("lisk"), .password("password")])

protocol Mappable {
   init?(rows: [String: Any])
}

struct DB {
   static func rows(from resultSet: ResultSet) -> [[String: Any]] {
      let ts = resultSet.rows.map {
         zip(resultSet.titles, $0)
      }
      let xs: [[String: Any]] = ts.map {
         var dictionaries: [String: Any] = [:]
         $0.forEach {
            let (title, value) = $0
            dictionaries[title] = value
         }
         return dictionaries
      }
      return xs
   }
}

func perfromQuery<A>(_ raw: String, fn: @escaping (ResultSet) -> A) -> Promise<A> {
   return Promise { resolve, reject in
      connection.connect() { error in
         if let error = error {
            return reject(error)
         }
         else {
            connection.execute(raw) { result in
               if let resultSet = result.asResultSet {
                  resolve(fn(resultSet))
               }
               else if let queryError = result.asError {
                  return reject(queryError)
               }
               defer { connection.closeConnection() }
            }
         }
      }
   }
}
