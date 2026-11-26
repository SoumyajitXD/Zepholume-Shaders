import it.unimi.dsi.fastutil.objects.Object2ObjectOpenHashMap;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Map;
import net.irisshaders.iris.Iris;
import net.irisshaders.iris.config.IrisConfig;
import net.irisshaders.iris.gl.blending.AlphaTest;
import net.irisshaders.iris.gl.blending.AlphaTestFunction;
import net.irisshaders.iris.gl.state.ShaderAttributeInputs;
import net.irisshaders.iris.pipeline.transform.PatchShaderType;
import net.irisshaders.iris.pipeline.transform.TransformPatcher;

class LoaderTransformProbe {
    public static void main(String[] args) throws Exception {
        Path target = Path.of(args[0]);
        Path config = target.resolve("fixture-iris.properties");
        var configConstructor = IrisConfig.class.getConstructors()[0];
        boolean modern = configConstructor.getParameterCount() == 2;
        if (modern) {
            // Supply the patcher's game-directory lookup without launching the client.
            Class<?> environment = Class.forName("net.fabricmc.api.EnvType");
            Class.forName("net.fabricmc.loader.impl.launch.knot.Knot").getConstructor(environment)
                    .newInstance(environment.getField("CLIENT").get(null));
            Class<?> loader = Class.forName("net.fabricmc.loader.impl.FabricLoaderImpl");
            Field gameDir = loader.getDeclaredField("gameDir");
            gameDir.setAccessible(true);
            gameDir.set(loader.getField("INSTANCE").get(null), target);
        }
        Field configField = Iris.class.getDeclaredField("irisConfig");
        configField.setAccessible(true);
        configField.set(null, modern
                ? configConstructor.newInstance(config, target.resolve("fixture-excluded.json"))
                : configConstructor.newInstance(config));
        Method vanilla = method("patchVanilla");
        Method terrain = method("patchSodium");
        for (String row : Files.readAllLines(target.resolve("cases.tsv"))) {
            String[] entry = row.split("\t");
            String id = entry[0];
            String program = entry[1];
            boolean overlay = entry[2].equals("True");
            boolean sky = program.startsWith("gbuffers_sky");
            boolean texture = !program.equals("gbuffers_basic") && !program.equals("gbuffers_skybasic");
            boolean light = !sky && !program.equals("gbuffers_basic")
                    && !program.equals("gbuffers_clouds") && !program.equals("gbuffers_armor_glint")
                    && !program.equals("gbuffers_textured");
            boolean useTerrainPatcher = program.equals("gbuffers_terrain") || program.equals("gbuffers_water");
            boolean useAlphaTest = program.equals("gbuffers_terrain") || program.equals("gbuffers_entities");
            var alpha = useAlphaTest ? new AlphaTest(AlphaTestFunction.GREATER, 0.1f) : AlphaTest.ALWAYS;
            var attributes = new ShaderAttributeInputs(true, texture, overlay, light, !sky);
            Object2ObjectOpenHashMap<?, ?> textures = new Object2ObjectOpenHashMap<>();
            String vertexSource = Files.readString(target.resolve(id + ".vsh"));
            String fragmentSource = Files.readString(target.resolve(id + ".fsh"));
            Object[] parameters;
            Method patch;
            if (useTerrainPatcher) {
                patch = terrain;
                parameters = modern
                        ? new Object[] {program, vertexSource, null, null, null, fragmentSource, alpha, textures}
                        : new Object[] {program, vertexSource, null, null, null, fragmentSource, alpha, attributes, textures};
            } else {
                patch = vanilla;
                parameters = modern
                        ? new Object[] {program, vertexSource, null, null, null, fragmentSource, alpha, false,
                                      !program.equals("gbuffers_clouds"), true, attributes, textures}
                        : new Object[] {program, vertexSource, null, null, null, fragmentSource, alpha, false,
                                      true, attributes, textures};
            }
            System.out.println("Transforming " + id);
            Map<?, ?> patched = (Map<?, ?>) patch.invoke(null, parameters);
            Files.writeString(target.resolve(id + ".vert"), (String) patched.get(PatchShaderType.VERTEX));
            Files.writeString(target.resolve(id + ".frag"), (String) patched.get(PatchShaderType.FRAGMENT));
        }
    }

    private static Method method(String name) {
        return Arrays.stream(TransformPatcher.class.getMethods())
                .filter(method -> method.getName().equals(name)).findFirst().orElseThrow();
    }
}
