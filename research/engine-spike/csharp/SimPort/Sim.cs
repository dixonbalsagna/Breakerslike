// C# port of research/engine-spike/shared/sim-ref.mjs. Throwaway spike code: nothing outside research/ may use it.
//
// Portability contract (same as the reference):
//  - Every real number is a double (IEEE-754 binary64). Only + - * / Math.Floor Math.Ceiling, comparisons and
//    % (C# double remainder, which is C fmod: truncated, exact, sign of the dividend) are used. No Math.Sin/Cos/Pow.
//  - Every expression is written in the same order as the JS so the evaluation order is identical. C# evaluates
//    operands left to right and never reassociates; RyuJIT does not contract a * b + c into an FMA on its own
//    (see notes/csharp.md for sources). Never use Math.FusedMultiplyAdd or *.MultiplyAddEstimate here.
//  - The RNG is mulberry32 on uint with unchecked wraparound, so Math.imul is a plain 32-bit uint multiply.
//  - Integer tick counts and column indices are ints; they are converted to double before any division.
using System;
using System.Collections.Generic;

namespace SimPort;

public static class Sim
{
    public const double W = 9600, COL = 8, HALF = 4800, TPS = 60;
    public const int NC = 1200;
    public const double DT = 1.0 / 60.0;          // Roslyn folds this with IEEE double division: same value as JS 1 / 60
    public const uint TERRAIN_SEED = 4242;
    public const double DEFORM_MIN = -260, SEA_BASE = -30;
    public const int NBEAMS = 6;

    // ---------------------------------------------------------------- wrap math
    public static double Wrap(double x) { return ((x % W) + W) % W; }
    public static double Sdx(double a, double b)
    {
        double d = (b - a) % W;
        if (d > HALF) d -= W; else if (d < -HALF) d += W;
        return d;
    }
    public static double Clamp(double v, double a, double b) { return v < a ? a : v > b ? b : v; }
    // Triangle wave in [0, 1] over an integer tick count. n and period arrive as ints and are widened to double,
    // exactly as JS holds them; % on these non-negative integer-valued doubles is exact.
    public static double Tri(double n, double period)
    {
        double p = (n % period) / period;
        return p < 0.5 ? 2 * p : 2 - 2 * p;
    }

    // ---------------------------------------------------------------- terrain
    public const int OCEAN = 0, PLAINS = 1, CITY = 2, VILLAGE = 3, FOREST = 4, DESERT = 5, MOUNTAINS = 6;
    public static readonly string[] BIOME_NAMES = { "ocean", "plains", "city", "village", "forest", "desert", "mountains" };
    static readonly double[] SEG_START = { 0, 1200, 1800, 2350, 3850, 4500, 5500, 6500, 7600, 8000, 8300 };
    static readonly double[] SEG_END = { 1200, 1800, 2350, 3850, 4500, 5500, 6500, 7600, 8000, 8300, 9600 };
    static readonly int[] SEG_BIOME = { 0, 3, 1, 2, 3, 4, 5, 6, 3, 1, 0 };

    public static int BiomeAt(double x)
    {
        x = Wrap(x);
        for (int s = 0; s < SEG_START.Length; s++) if (x >= SEG_START[s] && x < SEG_END[s]) return SEG_BIOME[s];
        return PLAINS;
    }

    static double[] Lattice(Rng rng, int cells)
    {
        var v = new double[cells];
        for (int k = 0; k < cells; k++) v[k] = rng.Next() * 2 - 1;
        return v;
    }

    // Value noise over column index i with `per` columns per lattice cell. The lattice wraps (NC % per == 0).
    static double VNoise(double[] v, int i, int per)
    {
        double c = (double)i / (double)per, k = Math.Floor(c), f = c - k, s = f * f * (3 - 2 * f);
        int ki = (int)k;                       // k is a non-negative integer-valued double
        double a = v[ki % v.Length], b = v[(ki + 1) % v.Length];
        return a + (b - a) * s;
    }

    public static double[] GenTerrain(uint seed)
    {
        var rng = new Rng(seed);
        double[] n1 = Lattice(rng, 12), n2 = Lattice(rng, 48), n3 = Lattice(rng, 150), m1 = Lattice(rng, 24);
        var t = new double[NC];
        for (int i = 0; i < NC; i++)
        {
            double x = i * COL; int b = BiomeAt(x);
            double n = 0.5 * VNoise(n1, i, 100) + 0.3 * VNoise(n2, i, 25) + 0.2 * VNoise(n3, i, 8);
            double h = 0;
            if (b == OCEAN) h = -340 + n * 35;
            else if (b == MOUNTAINS)
            {
                double k = Clamp((x - 6500) / 1100, 0, 1), env = 4 * k * (1 - k);
                double r = VNoise(m1, i, 50); if (r < 0) r = -r;
                h = env * (330 + 560 * r * (0.55 + 0.45 * VNoise(n3, i, 8)));
            }
            else if (b == DESERT) h = n * 28;
            else if (b == PLAINS) h = n * 16;
            else if (b == FOREST) h = 10 + n * 22;
            t[i] = h;
        }
        // Four passes of a 25-column box blur. Sum k = -12..12 in that order, then divide.
        double[] a = t, bf = new double[NC];
        for (int p = 0; p < 4; p++)
        {
            for (int i = 0; i < NC; i++)
            {
                double s = 0;
                for (int k = -12; k <= 12; k++) s += a[(i + k + NC) % NC];
                bf[i] = s / 25;
            }
            (a, bf) = (bf, a);
        }
        return a;
    }
}

// mulberry32, bit-identical to the reference. JS keeps `a` as an int32; the same 32 bits live in a uint here.
public sealed class Rng
{
    public uint A;
    public Rng(uint seed) { A = seed; }
    public uint U32()
    {
        unchecked
        {
            uint a = A = A + 0x6D2B79F5u;
            uint t = (a ^ (a >> 15)) * (1u | a);
            t = (t + (t ^ (t >> 7)) * (61u | t)) ^ t;
            return t ^ (t >> 14);
        }
    }
    public double Next() { return U32() / 4294967296.0; }
    public double Range(double lo, double hi) { return lo + (hi - lo) * Next(); }
    public uint State() { return A; }
}

public sealed class Terrain
{
    public readonly double[] Base;
    public readonly double[] Deform = new double[Sim.NC];
    public int Version;                       // bumped on every change; renderers re-upload heights when it moves

    public Terrain(uint seed = Sim.TERRAIN_SEED) { Base = Sim.GenTerrain(seed); }
    public double Height(int i) { return Base[i] + Deform[i]; }
    public bool IsSea(int i) { return Base[i] < Sim.SEA_BASE; }

    public double GroundY(double x)
    {
        double c = Sim.Wrap(x) / Sim.COL, id = Math.Floor(c), f = c - id;
        int i = (int)id, j = (i + 1) % Sim.NC;
        double a = Base[i] + Deform[i], b = Base[j] + Deform[j];
        return a + (b - a) * f;
    }

    // Bowl crater with a (1 - u^2)^2 falloff, clamped so the planet never goes below DEFORM_MIN of deformation.
    public void Crater(double x, double r, double depth)
    {
        int c0 = (int)Math.Floor(Sim.Wrap(x) / Sim.COL), n = (int)Math.Ceiling(r / Sim.COL);
        for (int k = -n; k <= n; k++)
        {
            int i = (c0 + k + Sim.NC) % Sim.NC;
            double u = (k < 0 ? -k : k) * Sim.COL / r; if (u > 1) u = 1;
            double f = 1 - u * u;
            double v = Deform[i] - depth * f * f;
            Deform[i] = v < Sim.DEFORM_MIN ? Sim.DEFORM_MIN : v;
        }
        Version++;
    }
}

public sealed class Fighter
{
    public double X, Y, VX, VY, TVX, TVY;
    public Fighter(double x, double y) { X = x; Y = y; }
}

public sealed class Beam
{
    public double SX, SY, TX, TY; public int Owner;
}

public struct SimEvent
{
    public int Kind; public double X, Y, R;         // kind 0 crater, 1 big crater
    public SimEvent(int kind, double x, double y, double r) { Kind = kind; X = x; Y = y; R = r; }
}

// Every scene exposes tick, terrain, a, b, beams, events (this tick only), Step() and the optional input hook.
public abstract class Scene
{
    public string Name = "";
    public readonly Terrain Terrain = new Terrain();
    public Rng? Rng;
    public int Tick;
    public readonly Fighter A, B;
    public Beam[] Beams = Array.Empty<Beam>();
    public readonly List<SimEvent> Events = new List<SimEvent>(8);

    protected Scene(Fighter a, Fighter b) { A = a; B = b; }
    public abstract void Step();
    public virtual void SetInput(double ix, double iy) { }

    public static Scene Make(string name, uint? seed = null)
    {
        if (name == "worst") return new WorstScene(seed ?? 7);
        if (name == "flight") return new FlightScene(seed ?? 11);
        return new ScriptScene(name);
    }

    // The bytes hashed are the little-endian doubles of this array, in this order (see Program.Sha).
    public double[] StateVector()
    {
        var v = new double[Sim.NC + 10];
        Array.Copy(Terrain.Deform, v, Sim.NC);
        v[Sim.NC] = A.X; v[Sim.NC + 1] = A.Y; v[Sim.NC + 2] = A.VX; v[Sim.NC + 3] = A.VY;
        v[Sim.NC + 4] = B.X; v[Sim.NC + 5] = B.Y; v[Sim.NC + 6] = B.VX; v[Sim.NC + 7] = B.VY;
        v[Sim.NC + 8] = Rng != null ? Rng.State() : 0;
        v[Sim.NC + 9] = Tick;
        return v;
    }
}

// Worst case for the benchmark: six beams that never stop, 60 craters a second, a power-up crater every two seconds.
public sealed class WorstScene : Scene
{
    public WorstScene(uint seed = 7) : base(new Fighter(0, 0), new Fighter(0, 0))
    {
        Name = "worst";
        Rng = new Rng(seed);
        Beams = new Beam[Sim.NBEAMS];
        for (int i = 0; i < Sim.NBEAMS; i++) Beams[i] = new Beam { Owner = i < 3 ? 0 : 1 };
        Place(0);
        AimBeams(0);
    }

    void Place(int n)
    {
        double c = Sim.Wrap(2400 + 10.0 * n);
        double sep = 300 + 4300 * Sim.Tri(n, 600);
        A.X = Sim.Wrap(c - sep / 2); B.X = Sim.Wrap(c + sep / 2);
        A.Y = 150 + 750 * Sim.Tri(n, 420); B.Y = 150 + 750 * Sim.Tri(n + 210, 420);
    }

    void AimBeams(int n)
    {
        for (int i = 0; i < Sim.NBEAMS; i++)
        {
            Fighter src = i < 3 ? A : B; double dir = i < 3 ? 1 : -1; Beam bm = Beams[i];
            bm.SX = src.X; bm.SY = src.Y + 40;
            bm.TX = Sim.Wrap(src.X + dir * (250 + 900 * Sim.Tri(n + 37 * i, 180 + 30 * i)));
            bm.TY = Terrain.GroundY(bm.TX);
        }
    }

    public override void Step()
    {
        int n = ++Tick;
        Events.Clear();
        Place(n);
        AimBeams(n);
        Rng rng = Rng!;
        for (int i = 0; i < Sim.NBEAMS; i++)
        {
            if (n % 6 != i) continue;
            Beam bm = Beams[i];
            double r = rng.Range(40, 120), depth = rng.Range(10, 30);
            Terrain.Crater(bm.TX, r, depth);
            bm.TY = Terrain.GroundY(bm.TX);
            Events.Add(new SimEvent(0, bm.TX, bm.TY, r));
        }
        if (n % 120 == 60)
        {
            Fighter f = (n / 120) % 2 == 0 ? A : B;       // n > 0, so int division is Math.floor(n / 120)
            Terrain.Crater(f.X, 300, 80);
            Events.Add(new SimEvent(1, f.X, Terrain.GroundY(f.X), 300));
        }
    }
}

// Free flight for the demo: two boxes steer toward seeded random velocities; SetInput() lets a human fly box a.
public sealed class FlightScene : Scene
{
    double ix, iy; bool human;

    public FlightScene(uint seed = 11) : base(new Fighter(9300, 400), new Fighter(250, 500))
    {
        Name = "flight";
        Rng = new Rng(seed);
    }

    public override void SetInput(double x, double y) { human = true; ix = Sim.Clamp(x, -1, 1); iy = Sim.Clamp(y, -1, 1); }

    void Steer(Fighter f, int idx, int n)
    {
        Rng rng = Rng!;
        if (n % 90 == idx * 45) { f.TVX = rng.Range(-1800, 1800); f.TVY = rng.Range(-300, 300); }
        if (idx == 0 && human) { f.TVX = ix * 1800; f.TVY = iy * 600; }
        f.VX = f.VX + (f.TVX - f.VX) * 0.05;
        f.VY = f.VY + (f.TVY - f.VY) * 0.05;
        f.X = Sim.Wrap(f.X + f.VX * Sim.DT);
        double y = f.Y + f.VY * Sim.DT;
        double g = Terrain.GroundY(f.X) + 30;
        if (y < g) { y = g; if (f.VY < 0) f.VY = 0; }
        if (y > 2400) { y = 2400; if (f.VY > 0) f.VY = 0; }
        f.Y = y;
    }

    public override void Step()
    {
        int n = ++Tick;
        Events.Clear();
        Steer(A, 0, n);
        Steer(B, 1, n);
        if (n % 30 == 0)
        {
            Rng rng = Rng!;
            Fighter f = rng.Next() < 0.5 ? A : B;
            double r = rng.Range(60, 160), depth = rng.Range(20, 60);
            Terrain.Crater(f.X, r, depth);
            Events.Add(new SimEvent(0, f.X, Terrain.GroundY(f.X), r));
        }
    }
}

// Scripted paths for the seam and camera tests. Positions are closed-form in the tick count.
public sealed class ScriptScene : Scene
{
    readonly string kind;

    public ScriptScene(string kind) : base(new Fighter(0, 0), new Fighter(0, 0))
    {
        Name = kind; this.kind = kind;
        if (kind != "sweep" && kind != "chase" && kind != "orbit" && kind != "climb")
            throw new ArgumentException("unknown script " + kind);
        Place(0);
    }

    void Place(int n)
    {
        Fighter a = A, b = B;
        if (kind == "sweep") { a.X = Sim.Wrap(9000 + 25.0 * n); b.X = Sim.Wrap(9000 - 25.0 * n); a.Y = 300; b.Y = 500; }
        else if (kind == "chase") { a.X = Sim.Wrap(9100 + 20.0 * n); b.X = Sim.Wrap(9300 + 22.0 * n); a.Y = 400; b.Y = 450; }
        else if (kind == "orbit")
        {
            double c = Sim.Wrap(9000 + 5.0 * n), s = 4500 + 600 * Sim.Tri(n, 240);
            a.X = Sim.Wrap(c - s / 2); b.X = Sim.Wrap(c + s / 2); a.Y = 300; b.Y = 350;
        }
        else // climb
        {
            double c = Sim.Wrap(9400 + 8.0 * n), s = 100 + 4600 * Sim.Tri(n, 900);
            a.X = Sim.Wrap(c - s / 2); b.X = Sim.Wrap(c + s / 2); a.Y = 100; b.Y = 100 + 2000 * Sim.Tri(n, 300);
        }
    }

    public override void Step() { int n = ++Tick; Events.Clear(); Place(n); }
}
