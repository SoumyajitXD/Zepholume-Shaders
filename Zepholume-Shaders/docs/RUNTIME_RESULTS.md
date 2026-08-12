# Runtime results

Status: **runtime rendering verification remains unperformed** as of 2026-08-02.

Update, 2026-07-31: the saved Iris and Oculus evidence manifests are empty. There are no complete logs, compile logs, patched shaders, options, profile selections, or screenshots to inspect, so the reported cursed sky/cloud appearance was not reproduced and cannot be attributed to either loader or profile. The corrected final package has been prepared for manual retest; this is not runtime validation.

No Zepholume build was loaded by Iris or Oculus in this stage. Existing complete logs were inspected without modifying either instance; they show no selected valid shader pack, so they cannot establish Zepholume compilation, linking, rendering, profile switching, or performance. The 0.2.0 isolated-package verification passes but is not a launch result.

The local Iris candidate is Minecraft 1.20.1 Fabric with Iris 1.7.6 and Sodium 0.5.13. The local Oculus candidate is Minecraft 1.20.1 Forge with Oculus 1.8.0 and Embeddium 0.3.31. Both use Java 17 according to launcher runtime metadata. The latter is a normal modpack with saves. No authenticated launcher process or documented local command-line launch mechanism was available without exposing credentials.

For a safe manual continuation, use a disposable copy of each instance, copy the final ZIP into its `shaderpacks` directory, back up `iris.properties` or `oculus.properties`, enable Iris debug mode with Ctrl+D and restart, select Zepholume, then provide complete post-launch logs and `patched_shaders` output. Preserve graphics settings and restore the selected pack after testing.
