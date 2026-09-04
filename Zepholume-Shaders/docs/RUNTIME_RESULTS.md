# Runtime results

Status: **V1.0.3-dev graphical runtime verification remains unperformed** as of 2026-09-02. Project-local Iris and Oculus runtime-readiness checks verify isolated files, hashes, Java 17, and package shape; they do not launch Minecraft or establish compilation, linking, rendering, screenshots, or performance.

Update, 2026-07-31: the saved Iris and Oculus evidence manifests are empty. There are no complete logs, compile logs, patched shaders, options, profile selections, or screenshots to inspect, so the reported cursed sky/cloud appearance was not reproduced and cannot be attributed to either loader or profile. The corrected final package has been prepared for manual retest; this is not runtime validation.

No V1.0.3-dev build has been loaded by Iris or Oculus in this stage. Existing complete logs were inspected without modifying either instance; they show no selected valid shader pack, so they cannot establish Zepholume compilation, linking, rendering, profile switching, underwater appearance, or performance. An isolated runtime-readiness check is not a launch result.

The local Iris candidate is Minecraft 1.20.1 Fabric with Iris 1.7.6 and Sodium 0.5.13. The local Oculus candidate is Minecraft 1.20.1 Forge with Oculus 1.8.0 and Embeddium 0.3.31. Both use Java 17 according to launcher runtime metadata and are isolated project-local directories. No authenticated launcher process or documented local command-line launch mechanism was used, so no runtime launch result exists.

For safe manual continuation, use the existing disposable isolated instances, select `Zepholume-Shaders-1.0.3-dev.zip`, enable the loader's debug output where available, then retain post-launch logs and `patched_shaders` output. Preserve graphics settings and restore the selected pack after testing. The required visual matrix includes cave entrances/interiors, block-light combinations, water at noon/sunset/night/rain, and underwater caves with and without night vision.
