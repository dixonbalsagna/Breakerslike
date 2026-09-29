// C# port of research/engine-spike/shared/camera-ref.mjs. Presentation layer: it reads sim state and never writes it.
// Stepped once per sim tick. Same portability contract as Sim.cs: doubles, + - * / only, expressions in written order.
namespace SimPort;

public static class Cam
{
    public const double MARGIN_X = 700, MARGIN_Y = 500;
    public const double ASPECT = 16.0 / 9.0;       // Roslyn folds with IEEE double division: same value as JS 16 / 9
    public const double MIN_VIEW = 1400, MAX_VIEW = 7200, HYST = 400, K = 0.12, PAN_MAX = 0.03, FLIP_DONE = 0.05;
    public const double Y_OFF = 40, Y_MIN = -180, Y_MAX = 2400;
    public const double VFOV_DEG = 40;
    public const double TAN_HALF_HFOV = 0.6470581942510264;   // tan(20 deg) * 16/9, precomputed so no libm is needed
}

// A point the camera frames: the camera only reads x and y (the tests feed it shifted copies of the fighters).
public struct Pt
{
    public double X, Y;
    public Pt(double x, double y) { X = x; Y = y; }
    public static Pt Of(Fighter f) { return new Pt(f.X, f.Y); }
}

public sealed class Camera
{
    public double X, Y, ViewW = Cam.MIN_VIEW, D, O, AX;
    public int Flips;
    public bool Flipping, Ready;

    // Returns the target (x, y, viewW) for the current arc d.
    void Target(in Pt a, in Pt b, out double tx, out double ty, out double tw)
    {
        double ad = D < 0 ? -D : D;
        double dy = a.Y - b.Y, ady = dy < 0 ? -dy : dy;
        double spanX = ad + Cam.MARGIN_X, spanY = (ady + Cam.MARGIN_Y) * Cam.ASPECT;
        tx = Sim.Wrap(a.X + D / 2);
        ty = Sim.Clamp((a.Y + b.Y) / 2 + Cam.Y_OFF, Cam.Y_MIN, Cam.Y_MAX);
        tw = Sim.Clamp(spanX > spanY ? spanX : spanY, Cam.MIN_VIEW, Cam.MAX_VIEW);
    }

    // Snap to the pair with no smoothing (scene start).
    public void Reset(in Pt a, in Pt b)
    {
        D = Sim.Sdx(a.X, b.X);
        Target(a, b, out double tx, out double ty, out double tw);
        X = tx; Y = ty; ViewW = tw; Ready = true; Flipping = false;
        O = 0; AX = a.X;
    }

    public void Step(in Pt a, in Pt b)
    {
        if (!Ready) { Reset(a, b); return; }
        double raw = Sim.Sdx(a.X, b.X), dPrev = D;
        D = D + Sim.Sdx(D, raw);
        double ad = D < 0 ? -D : D;
        if (ad > Sim.HALF + Cam.HYST) { D = raw; Flips++; Flipping = true; }
        Target(a, b, out double tx, out double ty, out double tw);
        O = O + Sim.Sdx(AX, a.X) + (D - dPrev) / 2;
        AX = a.X;
        double oa = O < 0 ? -O : O;
        if (oa < Sim.HALF / 2) O = Sim.Sdx(X, tx);
        double mx = O * Cam.K;
        double cap = ViewW * Cam.PAN_MAX;
        if (mx > cap) mx = cap; else if (mx < -cap) mx = -cap;
        X = Sim.Wrap(X + mx);
        O = O - mx;
        if (Flipping && (O < 0 ? -O : O) < ViewW * Cam.FLIP_DONE) Flipping = false;
        Y = Y + (ty - Y) * Cam.K;
        ViewW = ViewW + (tw - ViewW) * Cam.K;
    }

    public double ViewH() { return ViewW / Cam.ASPECT; }
    // World position to normalised screen coordinates: (0, 0) top left, (1, 1) bottom right.
    public double ScreenX(double x) { return 0.5 + Sim.Sdx(X, x) / ViewW; }
    public double ScreenY(double y) { return 0.5 - (y - Y) / ViewH(); }
    // Perspective renderers: distance from the camera to the z = 0 plane so that it shows exactly viewW.
    public double Distance() { return (ViewW / 2) / Cam.TAN_HALF_HFOV; }

    public double[] Vector() { return new double[] { X, Y, ViewW, D, O, Flips }; }
}
