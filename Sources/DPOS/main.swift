// Created by Sinisa Drpa on 10/26/18.

import Foundation
import Utility

let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
let parser = ArgumentParser(usage: "<options>", overview: "It calculates Lisk DPOS rewards")
let name: OptionArgument<String> = parser.add(option: "--group", shortName: "-g", kind: String.self, usage: "A group name (e.g. GDT, Elite)")
let address: OptionArgument<String> = parser.add(option: "--address", shortName: "-a", kind: String.self, usage: "An account address (e.g. 2797084409072178585L")

extension String: Error {}

struct Params {
   let group: String
   let address: String
}

func processArguments(arguments: ArgumentParser.Result) throws -> Params {
   guard let name = arguments.get(name) else {
      throw "A group name is required."
   }
   guard let address = arguments.get(address) else {
      throw "An account address is required."
   }
   return Params(group: name, address: address)
}

do {
   let parsedArguments = try parser.parse(arguments)
   let params = try processArguments(arguments: parsedArguments)
   Stat.calculate(params: params)
}
catch let error as ArgumentParserError {
   print(error.description)
}
catch let error {
   print(error)

   guard let appName = ProcessInfo.processInfo.arguments.first?.components(separatedBy: "/").last else { fatalError() }
   print("Example: ./\(appName) --group Elite --account 2797084409072178585L")
}
