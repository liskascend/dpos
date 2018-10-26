// Created by Sinisa Drpa on 10/26/18.

import Foundation
import SwiftKuery
import SwiftKueryPostgreSQL
import Then
import Yaml

struct Delegate {
   let name: String
   let share: Double
   let address: String?
   let publicKey: String?
   let voters: [Voter]?

   init(name: String, share: Double, address: String? = nil, publicKey: String? = nil, voters: [Voter]? = nil) {
      self.name = name
      self.share = share
      self.address = address
      self.publicKey = publicKey
      self.voters = voters
   }
}

struct Voter {
   let address: String
   let balance: Double
}

extension Double {
   func rescaling(min: Double, max: Double, min1: Double, max1: Double) ->  Double {
      return (max1-min1) / (max-min) * (self-max) + max1
   }
}

/// Determine vote power distribution between voters
func distribution(voters: [Voter]) -> [(address: String, perc: Double)] {
   let sum = voters.reduce(0.0) { acc, curr in acc + curr.balance }
   return voters.map { voter in
      let value = voter.balance.rescaling(min: 0, max: sum, min1: 0, max1: 1)
      return (address: voter.address, perc: value)
   }
}

struct Manager {
   static func yaml(filePath: String) -> Yaml {
      do {
         let contents = try String(contentsOfFile: filePath)
         let yaml = try Yaml.load(contents)
         return yaml
      } catch let e {
         fatalError(e.localizedDescription)
      }
   }

   static func delegates(yaml: Yaml) -> [Delegate] {
      guard let pools = yaml["pools"].array else { fatalError() }
      var delegates: [Delegate] =  []
      for pool in pools {
         guard let name = pool["delegate"].string,
            let share = pool["share"].double else {
               fatalError()
         }
         let delegate = Delegate(name: name, share: share)
         delegates.append(delegate)
      }
      return delegates
   }

   static func namesForGroup(_ groupName: String, yaml: Yaml) -> [String]? {
      guard let groups = yaml["groups"].dictionary else { fatalError() }
      guard let members = groups[.string(groupName)]?["members"].array else { fatalError() }
      var names: [String] =  []
      for name in members {
         guard let name = name.string else { fatalError() }
         names.append(name)
      }
      return names
   }
}

let filePath = "/Users/sdrpa/Desktop/DPOS/lisk.yml" // https://github.com/vekexasia/dpos-tools-data/blob/master/lisk.yml
let yaml = Manager.yaml(filePath: filePath)
let group: [String]? = Manager.namesForGroup("sherwood", yaml: yaml)
let delegates = Manager.delegates(yaml: yaml)

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

let me = Voter(address: "dummy", balance: 1_000)
let forgedPerMonth = 10_088.0

guard let pool = theGroup else { fatalError() }

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
