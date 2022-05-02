import Arm64ToSim
import Foundation

/// Adds arm64 simulator support to a framework
public struct AddArm64Simulator {
  var run: (Path, Path, Log?) throws -> Void

  /// Add arm64 simulator support to a framework
  /// - Parameters:
  ///   - deviceFramework: Path to device framework file
  ///   - simulatorFramework: Path to simulator framework file
  ///   - log: Log action (defaults to nil for no logging)
  /// - Throws: Error
  public func callAsFunction(deviceFramework: Path, simulatorFramework: Path, _ log: Log? = nil) throws {
    try run(deviceFramework, simulatorFramework, log)
  }
}

public extension AddArm64Simulator {
  static func live(
    runShellCommand: RunShellCommand = .live(),
    lipoThin: LipoThin = .live(),
    lipoCrate: LipoCreate = .live(),
    arm64ToSim: @escaping (String) throws -> Void = arm64ToSim(_:),
    deletePath: DeletePath = .live()
  ) -> Self {
    .init { deviceFramework, simulatorFramework, log in
      log?(.normal, "[AddArm64Simulator]")
      log?(.verbose, "- deviceFramework: \(deviceFramework.string)")
      log?(.verbose, "- simulatorFramework: \(simulatorFramework.string)")
      let deviceBinary = deviceFramework.addingComponent(deviceFramework.filenameExcludingExtension)
      let simulatorBinary = simulatorFramework.addingComponent(simulatorFramework.filenameExcludingExtension)
      let arm64Binary = Path("\(simulatorBinary.string)-arm64")
      try lipoThin(input: deviceBinary, arch: .arm64, output: arm64Binary, log?.indented())
      //try arm64ToSim(arm64Binary.string)

      /**
      *  Below is additional processing to correct this error: "The file is not a correct arm64 binary.
      *  Try thinning (via lipo) or unarchiving (via ar) first". The solution was to run arm64-to-sim
      *  on each object file individually.
      *
      *    % ar x slice.arm64                           // Extract *.o files from slice
      *    % for i in *.o ; do arm64-to-sim $i ; done   // Convert *.o to arm64-simulator
      *    % ar crv slice.arm64 *.o                     // Reassemble arm64 slice
      */

      let arm64ToSimBinary = "/path/to/arm64-to-sim"

      _ = try runShellCommand(
        "ar x \(arm64Binary.string)",
        log?.indented()
      )
      _ = try runShellCommand(
        "for i in *.o ; do \(arm64ToSimBinary) $i ; done",
        log?.indented()
      )
      _ = try runShellCommand(
        "ar crv \(arm64Binary.string) *.o",
        log?.indented()
      )
      _ = try runShellCommand(
        "rm *.o",
        log?.indented()
      )

      try lipoCrate(inputs: [simulatorBinary, arm64Binary], output: simulatorBinary, log?.indented())
      try deletePath(arm64Binary, log?.indented())
    }
  }
}
