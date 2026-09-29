// C# port of research/engine-spike/shared/test-ref.mjs: golden hashes, camera seam tests and simbench.
//   dotnet run -c Release --project research/engine-spike/csharp/SimPort              verify against golden.json
//   dotnet run -c Release --project research/engine-spike/csharp/SimPort -- --bench   also time the sim (SIMBENCH)
//   ... -- --golden <path>                                                             use another golden.json
//   ... -- --bench --reps <n>                                                          more simbench runs (default 5)
// Exits 0 when every check passes and 1 otherwise. Apart from the SIMBENCH line, the output is meant to be
// byte-identical to the Node reference's output (numbers are printed with JavaScript's Number formatting rules).
// It never writes golden.json: the goldens belong to the reference (shared/ is read-only for ports).
using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SimPort;

public static class Program
{
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    // ---------------------------------------------------------------- golden hashes
    static readonly (string Name, int[] Ticks)[] CHECKPOINTS =
    {
        ("worst", new[] { 600, 1980, 3600 }),
        ("flight", new[] { 600, 1800, 3600 }),
        ("flight-input", new[] { 600, 1800, 3600 }),   // replay test: box a is flown by a scripted input stream
    };
    static readonly string[] CAMERA_SCENES = { "sweep", "chase", "orbit", "climb", "flight", "worst" };
    const int CAMERA_TICKS = 3600;

    // Input stream for the replay golden: called before every step with the tick about to run.
    public static void ScriptedInput(int n, out double ix, out double iy)
    {
        ix = Sim.Tri(n, 240) * 2 - 1;
        iy = Sim.Tri(n + 50, 150) * 2 - 1;
    }

    // SHA-256 of the little-endian float64 bytes, lowercase hex (same as the reference's Buffer over a Float64Array).
    public static string Sha(double[] v)
    {
        var bytes = new byte[v.Length * 8];
        for (int i = 0; i < v.Length; i++) BinaryPrimitives.WriteDoubleLittleEndian(bytes.AsSpan(i * 8, 8), v[i]);
        return Convert.ToHexStringLower(SHA256.HashData(bytes));
    }

    sealed class Goldens
    {
        public string TerrainBase = "";
        public readonly Dictionary<string, Dictionary<int, string>> Checkpoints = new();
        public readonly Dictionary<string, (string Hash, int Flips)> Camera = new();
    }

    static Goldens ComputeGoldens()
    {
        var g = new Goldens();
        g.TerrainBase = Sha((double[])new Terrain(Sim.TERRAIN_SEED).Base.Clone());
        foreach (var (name, ticks) in CHECKPOINTS)
        {
            bool input = name == "flight-input";
            Scene s = Scene.Make(input ? "flight" : name);
            var rec = new Dictionary<int, string>();
            int t = 0;
            foreach (int tk in ticks)
            {
                while (t < tk)
                {
                    if (input) { ScriptedInput(t + 1, out double ix, out double iy); s.SetInput(ix, iy); }
                    s.Step(); t++;
                }
                rec[tk] = Sha(s.StateVector());
            }
            g.Checkpoints[name] = rec;
        }
        foreach (string name in CAMERA_SCENES)
        {
            Scene s = Scene.Make(name); var cam = new Camera();
            cam.Reset(Pt.Of(s.A), Pt.Of(s.B));
            for (int i = 0; i < CAMERA_TICKS; i++) { s.Step(); cam.Step(Pt.Of(s.A), Pt.Of(s.B)); }
            g.Camera[name] = (Sha(cam.Vector()), cam.Flips);
        }
        return g;
    }

    // ---------------------------------------------------------------- camera seam tests
    const double JUMP = 0.05;
    static readonly double[] OFFSETS = { 0.5, 1234.5, Sim.HALF, Sim.W - 0.25, 7777.77 };

    sealed class CamResult
    {
        public string Scene = ""; public int Ticks, SeamCrossings, Flips, FlipTicks, OutOfFrameTicks, OutOfFrameDuringFlip;
        public double MaxScreenJump, MaxSeamOffsetDiff; public bool Pass;
        public string Json()
        {
            return "{\"scene\":\"" + Scene + "\",\"ticks\":" + Ticks + ",\"seamCrossings\":" + SeamCrossings +
                   ",\"flips\":" + Flips + ",\"flipTicks\":" + FlipTicks + ",\"outOfFrameTicks\":" + OutOfFrameTicks +
                   ",\"outOfFrameDuringFlip\":" + OutOfFrameDuringFlip + ",\"maxScreenJump\":" + JsNum(MaxScreenJump) +
                   ",\"maxSeamOffsetDiff\":" + JsNum(MaxSeamOffsetDiff) + ",\"pass\":" + (Pass ? "true" : "false") + "}";
        }
    }

    static Pt Shifted(Fighter f, double off) { return new Pt(Sim.Wrap(f.X + off), f.Y); }

    static CamResult CameraTest(string name, int ticks = CAMERA_TICKS)
    {
        Scene s = Scene.Make(name);
        var cams = new Camera[OFFSETS.Length + 1];
        for (int k = 0; k < cams.Length; k++) cams[k] = new Camera();
        cams[0].Reset(Pt.Of(s.A), Pt.Of(s.B));
        for (int k = 0; k < OFFSETS.Length; k++) cams[k + 1].Reset(Shifted(s.A, OFFSETS[k]), Shifted(s.B, OFFSETS[k]));
        double[]? prev = null;
        double maxJump = 0, maxInv = 0;
        int outNormal = 0, outFlip = 0, flipTicks = 0, seamCross = 0;
        double pa = s.A.X, pb = s.B.X;
        var sk = new double[4];
        for (int i = 0; i < ticks; i++)
        {
            s.Step();
            if (Math.Abs(s.A.X - pa) > Sim.HALF) seamCross++;
            if (Math.Abs(s.B.X - pb) > Sim.HALF) seamCross++;
            pa = s.A.X; pb = s.B.X;
            cams[0].Step(Pt.Of(s.A), Pt.Of(s.B));
            for (int k = 0; k < OFFSETS.Length; k++) cams[k + 1].Step(Shifted(s.A, OFFSETS[k]), Shifted(s.B, OFFSETS[k]));
            Camera c = cams[0];
            var sc = new[] { c.ScreenX(s.A.X), c.ScreenY(s.A.Y), c.ScreenX(s.B.X), c.ScreenY(s.B.Y) };
            bool outOf = false;
            foreach (double v in sc) if (v < 0 || v > 1) { outOf = true; break; }
            if (c.Flipping) flipTicks++;
            if (outOf) { if (c.Flipping) outFlip++; else outNormal++; }
            if (prev != null && !c.Flipping)
                for (int k = 0; k < 4; k += 2) maxJump = Math.Max(maxJump, Math.Abs(sc[k] - prev[k]));
            prev = sc;
            for (int k = 0; k < OFFSETS.Length; k++)
            {
                Camera ck = cams[k + 1]; Pt a = Shifted(s.A, OFFSETS[k]), b = Shifted(s.B, OFFSETS[k]);
                sk[0] = ck.ScreenX(a.X); sk[1] = ck.ScreenY(a.Y); sk[2] = ck.ScreenX(b.X); sk[3] = ck.ScreenY(b.Y);
                for (int j = 0; j < 4; j++) maxInv = Math.Max(maxInv, Math.Abs(sk[j] - sc[j]));
                maxInv = Math.Max(maxInv, Math.Abs(ck.ViewW - c.ViewW) / c.ViewW);
                if (ck.Flips != c.Flips) maxInv = double.PositiveInfinity;
            }
        }
        var r = new CamResult
        {
            Scene = name, Ticks = ticks, SeamCrossings = seamCross, Flips = cams[0].Flips, FlipTicks = flipTicks,
            OutOfFrameTicks = outNormal, OutOfFrameDuringFlip = outFlip,
            MaxScreenJump = ToFixedNumber(maxJump, 5), MaxSeamOffsetDiff = maxInv,
        };
        r.Pass = outNormal == 0 && maxJump < JUMP && maxInv < 1e-6;
        return r;
    }

    // ---------------------------------------------------------------- sim throughput (simbench)
    static double sink;   // keeps the benchmarked work observable

    static string SimBench(int reps = 5, int ticks = 3600)
    {
        static double Now() { return Stopwatch.GetTimestamp() * 1000.0 / Stopwatch.Frequency; }
        var gen = new double[reps]; var run = new double[reps];
        for (int r = 0; r < reps; r++)
        {
            double t0 = Now(); double[] t = Sim.GenTerrain(Sim.TERRAIN_SEED); gen[r] = Now() - t0; sink += t[0];
        }
        for (int r = 0; r < reps; r++)
        {
            Scene s = Scene.Make("worst"); double t0 = Now();
            for (int i = 0; i < ticks; i++) s.Step();
            run[r] = (Now() - t0) / ticks; sink += s.Terrain.Deform[0];
        }
        static double Med(double[] a) { var c = (double[])a.Clone(); Array.Sort(c); return c[c.Length >> 1]; }
        var sb = new StringBuilder();
        sb.Append("{\"stack\":\"dotnet ").Append(Environment.Version.ToString()).Append(' ')
          .Append(RuntimeInformation.ProcessArchitecture.ToString().ToLowerInvariant()).Append('"');
        sb.Append(",\"reps\":").Append(reps).Append(",\"ticks\":").Append(ticks);
        sb.Append(",\"terrainGenMs\":").Append(JsNum(ToFixedNumber(Med(gen), 3)));
        sb.Append(",\"worstTickUs\":").Append(JsNum(ToFixedNumber(Med(run) * 1000, 3)));
        // Extra fields (not in the Node line): every run, and the JIT settings that change .NET timings.
        sb.Append(",\"terrainGenMsRuns\":[").Append(string.Join(",", Array.ConvertAll(gen, v => JsNum(ToFixedNumber(v, 3))))).Append(']');
        sb.Append(",\"worstTickUsRuns\":[").Append(string.Join(",", Array.ConvertAll(run, v => JsNum(ToFixedNumber(v * 1000, 3))))).Append(']');
        sb.Append(",\"runtime\":\"").Append(RuntimeInformation.FrameworkDescription).Append('"');
        sb.Append(",\"optimized\":").Append(IsOptimized() ? "true" : "false");
        sb.Append(",\"jitEnv\":{");
        bool first = true;
        foreach (string k in new[] { "DOTNET_TieredCompilation", "DOTNET_TieredPGO", "DOTNET_TC_QuickJitForLoops", "DOTNET_ReadyToRun", "DOTNET_OSR_HitLimit" })
        {
            string? v = Environment.GetEnvironmentVariable(k);
            if (v == null) continue;
            if (!first) sb.Append(','); first = false;
            sb.Append('"').Append(k).Append("\":\"").Append(v).Append('"');
        }
        sb.Append("}}");
        return sb.ToString();
    }

    static bool IsOptimized()
    {
        var attr = (DebuggableAttribute?)Attribute.GetCustomAttribute(typeof(Program).Assembly, typeof(DebuggableAttribute));
        return attr == null || !attr.IsJITOptimizerDisabled;
    }

    // ---------------------------------------------------------------- JavaScript number formatting
    // Number.prototype.toString (ECMA-262 Number::toString) from .NET's shortest round-trip digits ("R" is the
    // shortest round-trippable string since .NET Core 3.0), so the printed JSON matches JSON.stringify exactly.
    public static string JsNum(double v)
    {
        if (double.IsNaN(v) || double.IsInfinity(v)) return "null";      // JSON.stringify(Infinity) === 'null'
        if (v == 0) return "0";                                           // also -0
        string r = v.ToString("R", Inv);
        bool neg = r[0] == '-'; if (neg) r = r.Substring(1);
        int e = 0, ei = r.IndexOfAny(new[] { 'E', 'e' });
        if (ei >= 0) { e = int.Parse(r.Substring(ei + 1), NumberStyles.AllowLeadingSign, Inv); r = r.Substring(0, ei); }
        int dot = r.IndexOf('.');
        string ip = dot >= 0 ? r.Substring(0, dot) : r, fp = dot >= 0 ? r.Substring(dot + 1) : "";
        string all = ip + fp, digits = all.TrimStart('0');
        int n = ip.Length + e - (all.Length - digits.Length);             // value = 0.digits * 10^n
        digits = digits.TrimEnd('0');
        int k = digits.Length;
        string s;
        if (k <= n && n <= 21) s = digits + new string('0', n - k);
        else if (0 < n && n <= 21) s = digits.Substring(0, n) + "." + digits.Substring(n);
        else if (-6 < n && n <= 0) s = "0." + new string('0', -n) + digits;
        else
        {
            int x = n - 1;
            s = digits.Substring(0, 1) + (k > 1 ? "." + digits.Substring(1) : "") + "e" + (x < 0 ? "-" : "+") + Math.Abs(x);
        }
        return neg ? "-" + s : s;
    }

    // +x.toFixed(f): .NET Core 3.0+ formats "F<f>" from the exact binary value, rounding half away from zero,
    // which equals toFixed's "pick the larger n" for the non-negative values used here.
    static double ToFixedNumber(double v, int f) { return double.Parse(v.ToString("F" + f, Inv), Inv); }

    // ---------------------------------------------------------------- main
    static string? FindGolden(string? explicitPath)
    {
        if (explicitPath != null) return File.Exists(explicitPath) ? Path.GetFullPath(explicitPath) : null;
        foreach (string start in new[] { AppContext.BaseDirectory, Environment.CurrentDirectory })
        {
            for (var dir = new DirectoryInfo(start); dir != null; dir = dir.Parent)
            {
                foreach (string rel in new[] { Path.Combine("shared", "golden.json"), Path.Combine("research", "engine-spike", "shared", "golden.json") })
                {
                    string p = Path.Combine(dir.FullName, rel);
                    if (File.Exists(p) && File.Exists(Path.Combine(Path.GetDirectoryName(p)!, "sim-ref.mjs"))) return p;
                }
            }
        }
        return null;
    }

    public static int Main(string[] argv)
    {
        var args = new HashSet<string>(argv);
        string? goldenArg = null;
        for (int i = 0; i + 1 < argv.Length; i++) if (argv[i] == "--golden") goldenArg = argv[i + 1];
        string? goldenPath = FindGolden(goldenArg);
        if (goldenPath == null)
        {
            Console.WriteLine("FAIL golden.json not found (pass --golden <path to research/engine-spike/shared/golden.json>)");
            return 1;
        }

        Goldens g = ComputeGoldens();
        int fail = 0;
        using (JsonDocument doc = JsonDocument.Parse(File.ReadAllText(goldenPath)))
        {
            JsonElement want = doc.RootElement;
            void Cmp(string label, string a, string? b)
            {
                bool ok = a == b; if (!ok) fail++;
                Console.WriteLine((ok ? "PASS " : "FAIL ") + label + " " + a + (ok ? "" : " expected " + b));
            }
            static string? Get(JsonElement e, params string[] path)
            {
                foreach (string p in path) { if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty(p, out e)) return null; }
                return e.ValueKind == JsonValueKind.String ? e.GetString() : null;
            }
            Cmp("terrainBase", g.TerrainBase, Get(want, "terrainBase"));
            foreach (var (name, ticks) in CHECKPOINTS)
                foreach (int t in ticks) Cmp(name + "@" + t, g.Checkpoints[name][t], Get(want, name, t.ToString(Inv)));
            foreach (string n in CAMERA_SCENES) Cmp("camera." + n + "@" + CAMERA_TICKS, g.Camera[n].Hash, Get(want, "camera", n, "hash"));
        }
        foreach (string n in CAMERA_SCENES)
        {
            CamResult r = CameraTest(n);
            if (!r.Pass) fail++;
            Console.WriteLine((r.Pass ? "PASS" : "FAIL") + " camera " + r.Json());
        }
        if (args.Contains("--bench"))
        {
            int reps = 5;   // same protocol as the reference; --reps N is only for looking at JIT tiering
            for (int i = 0; i + 1 < argv.Length; i++) if (argv[i] == "--reps") reps = int.Parse(argv[i + 1], Inv);
            Console.WriteLine("SIMBENCH " + SimBench(reps));
        }
        if (fail > 0) { Console.WriteLine(fail + " failure(s)"); return 1; }
        Console.WriteLine("all reference checks passed");
        return 0;
    }
}
