// Created by Sinisa Drpa on 10/29/18.

import Foundation

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
