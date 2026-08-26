# Prism bootstrap repair

Status: repaired and automatically regression-tested; the replacement LAN bootstrap has not been imported or manually tested.

## Root cause

`bootstrap/template/instance.cfg`, `Build-Prism-Bootstrap.ps1`, and `Set-PackUrl.ps1` wrote this raw INI value:

```ini
PreLaunchCommand="$INST_JAVA" -jar packwiz-installer-bootstrap.jar <PACK_URL>
```

Those quote characters looked correct in a text editor but were not escaped for Prism's instance-config serialization. Prism consumed them as configuration syntax. The real manual repair made through Prism's UI was serialized with backslash-escaped embedded quotes:

```ini
PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar <PACK_URL>
```

That is now the generator's canonical form. After Prism decodes the INI value, the command it executes is:

```text
"$INST_JAVA" -jar packwiz-installer-bootstrap.jar <PACK_URL>
```

The executable and `-jar` remain distinct arguments, and the quoted executable works when Java is installed below a path containing spaces.

## Regression coverage

`scripts/Test-PrismBootstrapCommand.ps1`:

1. builds a fresh bootstrap through the production generator;
2. opens the ZIP and reads `instance.cfg` directly;
3. requires the escaped `$INST_JAVA` command exactly;
4. rejects `java.exe-jar`, `javaw.exe-jar`, and `$INST_JAVA-jar` patterns;
5. decodes the value as Prism does;
6. executes it from the generated Minecraft directory using the installed Java 17 path, which contains spaces;
7. observes the spawned Java process and proves `-jar packwiz-installer-bootstrap.jar` is a separate argument;
8. terminates only that disposable test process.

Result: **PASS**. Evidence is in `audit/prism-bootstrap-regression.json`.

The production `MilkyCraft-VanillaPlus-AutoUpdating-Prism.zip` and LAN bootstrap are both produced by `Build-Prism-Bootstrap.ps1`, so they share the correction. `Set-PackUrl.ps1` also preserves the correct escaped template when the final public URL is configured.

## Replacement LAN bootstrap

```text
dist/MilkyJ-VanillaPlus-1.9.0-rc1-LAN-TEST-r2-Prism.zip
SHA-256 3eac0a7fce9029d023182e276dea5da1695ad34b817c4f0582ea88d3fe34a907
```

Its generated command was inspected directly and contains:

```ini
PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar http://<PRIVATE_LAN_ADDRESS>:8765/packwiz/pack.toml
```

The R2 ZIP itself still needs an ordinary manual import/title-screen/join check when the RC gate resumes. It was not imported into the user's Prism application root during this repair.
