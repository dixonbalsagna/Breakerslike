// Engine spike probe: one C# script. It prints one line (runtime, platform, a wrap-math check) and quits,
// so an exported build exits by itself. Throwaway spike code (research/ only).
using Godot;

public partial class Main : Node2D
{
    const double W = 9600.0;

    static double Wrap(double x) { return ((x % W) + W) % W; }

    public override void _Ready()
    {
        double w = Wrap(-0.25);   // same expression as shared/sim-ref.mjs wrap(); must be exactly 9599.75
        GD.Print("WebProbe C# ok: runtime=" + System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription +
                 " os=" + OS.GetName() + " wrap(-0.25)=" + w.ToString("R", System.Globalization.CultureInfo.InvariantCulture));
        GetTree().Quit();
    }
}
