// Created by Sinisa Drpa on 10/29/18.

import Foundation
import Yaml

struct Delegate {
   let name: String
   let share: Double
   let address: String?
   let publicKey: String?
   let voters: [Voter]?

   init(name: String,
        share: Double,
        address: String? = nil,
        publicKey: String? = nil,
        voters: [Voter]? = nil) {
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

struct Stat {
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
         let upgrade = pool["upgrades"].array?.first
         let share2 = upgrade?["value"].double

         let delegate = Delegate(name: name, share: share2 ?? share)
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
