// Created by Sinisa Drpa on 10/29/18.

import Foundation
import SwiftKuery
import SwiftKueryPostgreSQL
import Then
import Yaml

extension Stat {
   static func calculate(params: Params) {
      print("Calculating reward from '\(params.group)'...")
      let filePath = "/Users/sdrpa/Desktop/DPOS/lisk.yml" // https://github.com/vekexasia/dpos-tools-data/blob/master/lisk.yml
      let yaml = Stat.yaml(filePath: filePath)
      let group: [String]? = Stat.namesForGroup(params.group.lowercased(), yaml: yaml)
      let delegates = Stat.delegates(yaml: yaml)

      // Get delegate info (address, publicKey)
      let theGroup = group?
         .compactMap({ name in
            delegates.first(where: { $0.name == name })
         })
         .compactMap({ delegate -> Delegate in
            struct Result: Mappable {
               let address: String
               let publicKey: String

               init(rows: [String : Any]) {
                  guard let address = rows["address"] as? String else { fatalError() }
                  guard let publicKey = rows["publicKey"] as? String else { fatalError() }
                  self.address = address
                  self.publicKey = publicKey
               }
            }

            guard let result = try? await(perfromQuery(
               """
               SELECT address, encode(mem_accounts."publicKey", 'hex') AS "publicKey"
               FROM mem_accounts
               WHERE username = '\(delegate.name)'
            """) { (resultSet: ResultSet) -> Result in
               guard let result = DB.rows(from: resultSet).map(Result.init(rows:)).first else { fatalError() }
               return result
            }) else { fatalError() }

            return Delegate(name: delegate.name, share: delegate.share, address: result.address, publicKey: result.publicKey)
         })
         .compactMap({ delegate -> Delegate in
            struct Result: Mappable {
               let address: String
               let balance: Double

               init(rows: [String : Any]) {
                  guard let address = rows["address"] as? String else { fatalError() }
                  guard let balance = rows["balance"] as? String else { fatalError() }
                  self.address = address
                  self.balance = Double(balance) ?? 0
               }
            }

            guard let publicKey = delegate.publicKey else { fatalError() }
            guard let results = try? await(perfromQuery(
               """
               SELECT accounts.address,
                  trunc(accounts.balance::numeric/100000000, 0) AS balance
               FROM mem_accounts2delegates delegates
               INNER JOIN mem_accounts accounts ON delegates."accountId" = accounts.address
               """ +
                  " WHERE delegates.\"dependentId\" = '" + publicKey + "'" +
               """
               ORDER BY accounts.balance DESC;
            """) { (resultSet: ResultSet) -> [Result] in
               let rows = DB.rows(from: resultSet).map(Result.init(rows:))
               return rows
            }) else { fatalError() }

            return Delegate(name: delegate.name, share: delegate.share, address: delegate.address, publicKey: delegate.publicKey, voters: results.map { Voter(address: $0.address, balance: $0.balance) })
         })
      //print(theGroup?.first?.name, theGroup?.first?.voters?.count)
      // Now we have complete info

      /// Get balance for address
      func getBalance(address: String) -> Double {
         struct Result: Mappable {
            let balance: Double

            init(rows: [String : Any]) {
               guard let balance = rows["balance"] as? String else { fatalError() }
               guard let asDouble = Double(balance) else { fatalError() }
               self.balance = asDouble
            }
         }

         guard let result = try? await(perfromQuery(
            """
            SELECT address, trunc(balance::numeric/100000000, 8) as balance
            FROM mem_accounts
            WHERE address = '\(address)'
         """) { (resultSet: ResultSet) -> Result in
            guard let result = DB.rows(from: resultSet).map(Result.init(rows:)).first else { fatalError() }
            return result
         }) else { fatalError() }

         return result.balance
      }

      let balance = getBalance(address: params.address)
      let me = Voter(address: params.address, balance: balance)
      let forgedPerMonth = 10_088.0

      guard let pool = theGroup else { fatalError() }

      print("---")
      print("Address: \(params.address). Balance: \(String(format: "%.2f LSK", balance))")
      print("---")
      var total = 0.0
      for delegate in pool {
         guard let voters = delegate.voters else { fatalError() }
         let dist = distribution(voters: voters + [me])
         let sum = dist.reduce(0.0) { acc, curr in acc + curr.perc }
         assert(sum >= 0.9 && sum <= 1.1)
         //print(dist.reduce(0.0, { acc, curr in acc + curr.perc }))
         let shared = forgedPerMonth * delegate.share / 100.0
         // (address: String, perc: Double)
         guard let votePower = dist.first(where: { $0.0 == me.address })?.perc else { fatalError() }
         let reward = shared * votePower

         let padding = 25
         let namePadded = delegate.name.padding(toLength: padding, withPad: " ", startingAt: 0)
         let sharePadded = "\(delegate.share)% = \(shared) LSK".padding(toLength: padding, withPad: " ", startingAt: 0)
         let rewardPadded = String(format: "%.3f LSK", reward).padding(toLength: padding, withPad: " ", startingAt: 0)
         print(namePadded + sharePadded + rewardPadded)
         total += reward
      }
      print("---\nTotal: \(String(format: "%.3f LSK", total))")
   }
}
