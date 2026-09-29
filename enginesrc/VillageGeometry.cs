using System;
using System.Globalization;

namespace MyBotEngine
{
    /// <summary>
    /// Maps between screen pixels and "village" coordinates for the Clash of Clans board.
    ///
    /// The board is drawn as an isometric grid centred on a fixed screen anchor. A village
    /// coordinate is the pixel it would sit at when the camera is fully zoomed out (zoom = 1);
    /// on screen it is pushed away from, or pulled toward, the anchor by the current zoom
    /// factor, then shifted by the village offset the caller measured for the current frame.
    ///
    /// The anchor and formulas are the board's projection geometry (facts about the grid),
    /// reproduced here from the observed input/output of the original library, not its code.
    /// Results are verified to match the original exactly (see enginesrc/tests).
    /// </summary>
    public static class VillageGeometry
    {
        // Screen anchor the board is scaled about. X and Y differ because the board is not
        // centred vertically in the capture.
        public const int AnchorX = 422;
        public const int AnchorY = 345;

        // Per-instance camera state, set by SetVillageOffset before any conversion.
        public static int OffsetX { get; private set; }
        public static int OffsetY { get; private set; }
        public static float ZoomFactor { get; private set; }

        public static void SetVillageOffset(int offsetX, int offsetY, float zoom)
        {
            OffsetX = offsetX;
            OffsetY = offsetY;
            ZoomFactor = zoom;
        }

        // Half-away-from-zero rounding on a float, matching the original's
        // Math.Round((float)..., MidpointRounding.AwayFromZero) followed by an int conversion.
        private static int RoundAway(float value)
        {
            return (int)Math.Round((double)value, MidpointRounding.AwayFromZero);
        }

        private static string Format(int x, int y)
        {
            return x.ToString(CultureInfo.InvariantCulture) + "|" + y.ToString(CultureInfo.InvariantCulture);
        }

        /// <summary>Scale a point about the anchor by <paramref name="zoom"/> (0 = use the stored zoom). No offset applied.</summary>
        public static string ConvertVillagePos(int x, int y, float zoom)
        {
            if (zoom == 0f) zoom = ZoomFactor;
            int sx = AnchorX - RoundAway((AnchorX - x) * zoom);
            int sy = AnchorY - RoundAway((AnchorY - y) * zoom);
            return Format(sx, sy);
        }

        /// <summary>Village coordinate -> current screen pixel: scale about the anchor, then add the offset.</summary>
        public static string ConvertToVillagePos(int x, int y, float zoom)
        {
            if (zoom == 0f) zoom = ZoomFactor;
            int sx = AnchorX - RoundAway((AnchorX - x) * zoom) + OffsetX;
            int sy = AnchorY - RoundAway((AnchorY - y) * zoom) + OffsetY;
            return Format(sx, sy);
        }

        /// <summary>Screen pixel -> village coordinate: the inverse of the scale-and-offset, using the stored zoom.</summary>
        public static string ConvertFromVillagePos(int x, int y)
        {
            int vx = AnchorX - RoundAway((AnchorX + OffsetX - x) / ZoomFactor);
            int vy = AnchorY - RoundAway((AnchorY + OffsetY - y) / ZoomFactor);
            return Format(vx, vy);
        }
    }
}
