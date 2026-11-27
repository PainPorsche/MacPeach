import Foundation

var failures = 0
func check(_ ok: Bool, _ name: String) {
    print(ok ? "ok   \(name)" : "FAIL \(name)")
    if !ok { failures += 1 }
}

let args = CommandLine.arguments
let setupURL = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2], isDirectory: true)
let fm = FileManager.default

let catalog = ShParser.parse(try String(contentsOf: setupURL, encoding: .utf8))
check(!catalog.formulae.isEmpty && !catalog.casks.isEmpty && !catalog.tweaks.isEmpty, "MacSetup.sh has all three pipelines")
check(catalog.tweaks.first { $0.commands.contains { $0.contains("LSQuarantine") } }?.security == .lowers, "LSQuarantine is marked @security lowers")
check(catalog.tweaks.filter { $0.commands.contains { $0.contains("socketfilterfw") } }.allSatisfy { $0.security == .raises }, "firewall settings are marked @security raises")
check(!ShParser.isSafePackageName("git; rm -rf ~") && !ShParser.isSafePackageName("$(id)") && ShParser.isSafePackageName("gromgit/fuse/ntfs-3g-mac"), "package name allow-list")

if var choice = catalog.tweaks.first(where: \.isChoice) {
    choice.selectedValue = "5; touch /tmp/pwned"
    check(!choice.resolvedCommands.joined().contains("pwned"), "unsafe @options value falls back to the default")
}

let big = out.appendingPathComponent("big.json")
try Data(count: 2_000).write(to: big)
check((try? SafeFile.read(big, limit: 1_000)) == nil, "SafeFile rejects a file over the limit")
check((try? SafeFile.read(out, limit: 1_000)) == nil, "SafeFile rejects a directory")
check((try? SafeFile.read(URL(fileURLWithPath: "/dev/zero"), limit: 1_000)) == nil, "SafeFile rejects /dev/zero")
check((try? SafeFile.read(big, limit: 5_000))?.count == 2_000, "SafeFile reads a regular file")

let env = Shell.environment()
check(env.keys.allSatisfy { !$0.hasPrefix("DYLD_") && $0 != "BASH_ENV" && $0 != "ENV" }, "no DYLD_* / BASH_ENV in child environment")

let scripts = out.appendingPathComponent("scripts", isDirectory: true)
try fm.createDirectory(at: scripts, withIntermediateDirectories: true)
func dump(_ name: String, _ body: String) throws {
    try body.write(to: scripts.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
for extra in ExtrasCatalog.all {
    for step in extra.steps {
        for lang in [Lang.pl, .en] { try dump("\(step.id).\(lang.rawValue).sh", ScriptGenerator.wrap(step.script(lang))) }
        if let c = step.check { try dump("\(step.id).check.sh", "#!/bin/bash\n" + c) }
    }
    if let undo = extra.undo { try dump("\(extra.id).undo.sh", ScriptGenerator.wrap(undo.script(.en))) }
}
try dump("homebrew.sh", ScriptGenerator.wrap(ScriptGenerator.installHomebrew(lang: .en)))
try dump("tweaks.sh", ScriptGenerator.wrap(ScriptGenerator.tweaks(catalog.tweaks, lang: .en)))
try dump("install.sh", ScriptGenerator.wrap(ScriptGenerator.install(formulae: catalog.formulae, casks: catalog.casks, lang: .en)))

exit(failures == 0 ? 0 : 1)
