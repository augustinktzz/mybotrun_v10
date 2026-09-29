using System;
using System.Reflection;
using MyBotEngine;

// Verifies VillageGeometry against the original library over a grid of inputs.
// Usage: GeometryParity <reference.dll>   (reference = de-protected original)
// The original guards these functions with checkLicence(); the reference build passed in
// here is the one with the anti-copycat module initializer removed (scratchpad/work/reference.dll),
// so the guarded methods run normally.
class GeometryParity
{
    static MethodInfo _conv, _to, _from, _setOff;

    static void BindOriginal(string path)
    {
        var asm = Assembly.LoadFile(System.IO.Path.GetFullPath(path));
        var dep = asm.GetType("MBRfunction.DebugEntryPoint", true);
        var flags = BindingFlags.Public | BindingFlags.Static;
        _conv = dep.GetMethod("ConvertVillagePos", flags);
        _to = dep.GetMethod("ConvertToVillagePos", flags);
        _from = dep.GetMethod("ConvertFromVillagePos", flags);
        _setOff = dep.GetMethod("setVillageOffset", flags);
    }

    static string Orig(MethodInfo m, params object[] args) => (string)m.Invoke(null, args);

    static int Main(string[] argv)
    {
        BindOriginal(argv[0]);

        int checks = 0, fails = 0;
        var zooms = new float[] { 1f, 0.5f, 0.75f, 1.5f, 2f, 0.833f, 1.234f };
        var offsets = new int[][] { new[] { 0, 0 }, new[] { 5, -7 }, new[] { -13, 21 }, new[] { 120, 90 } };

        foreach (var off in offsets)
        {
            int ox = off[0], oy = off[1];
            foreach (var z in zooms)
            {
                // set offset+zoom on both sides
                Orig(_setOff, ox, oy, z);
                VillageGeometry.SetVillageOffset(ox, oy, z);

                for (int x = -40; x <= 860; x += 37)
                {
                    for (int y = -40; y <= 780; y += 31)
                    {
                        Compare("ConvertVillagePos", Orig(_conv, x, y, 0f), VillageGeometry.ConvertVillagePos(x, y, 0f), x, y, z, ox, oy, ref checks, ref fails);
                        Compare("ConvertVillagePos(z)", Orig(_conv, x, y, z), VillageGeometry.ConvertVillagePos(x, y, z), x, y, z, ox, oy, ref checks, ref fails);
                        Compare("ConvertToVillagePos", Orig(_to, x, y, 0f), VillageGeometry.ConvertToVillagePos(x, y, 0f), x, y, z, ox, oy, ref checks, ref fails);
                        Compare("ConvertFromVillagePos", Orig(_from, x, y), VillageGeometry.ConvertFromVillagePos(x, y), x, y, z, ox, oy, ref checks, ref fails);
                    }
                }
            }
        }

        Console.WriteLine($"{checks} comparisons, {fails} mismatch(es)");
        return fails == 0 ? 0 : 1;
    }

    static void Compare(string fn, string expected, string actual, int x, int y, float z, int ox, int oy, ref int checks, ref int fails)
    {
        checks++;
        if (expected != actual)
        {
            fails++;
            if (fails <= 20)
                Console.WriteLine($"  DIFF {fn} x={x} y={y} z={z} off=({ox},{oy})  ref='{expected}' new='{actual}'");
        }
    }
}
