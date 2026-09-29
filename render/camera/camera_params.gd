class_name CamParams
## Every number of the dynamic split screen (docs/camera/split-screen.md), in one place. Screen fractions are of the
## screen height (vh) or width (vw) as named; times are seconds on the fixed 60 Hz step; distances are world units.
## Defaults marked "Orb decides" in the design doc are the ones a playtest will change.

# --- the trigger (section 2) ---
const R_SPLIT: float = 0.045           # split when a fighter's height falls under this fraction of vh (Orb decides)
const R_MERGE: float = 0.060           # merge when it stays above this (Orb decides)
const R_BEAM_MIN: float = 0.030        # a beam struggle keeps the merged wide shot down to this
const MIN_PX: float = 28.0             # under 600 px of screen height the split line is at least this many pixels
const SPLIT_DWELL: float = 0.25
const MERGE_DWELL: float = 0.40
const MIN_SPLIT_AGE: float = 1.2       # before a dissolve merge
const MIN_MERGED_AGE: float = 0.8      # before splitting again
const MIN_OUT_OF_FRAME_AGE: float = 0.25   # ... or this, when a fighter is already out of the one view
const CLOSING_LOOKAHEAD: float = 0.4   # do not open if the fighters will be back over the split line by then
const ZOOM_OUT_LOOKAHEAD: float = 0.3  # the one-view camera zooms for the separation it will have this soon, if growing
const FRAME_MARGIN: float = 0.46       # a fighter farther than this fraction of vw from the one-view centre opens the split at once
const BODY_H: float = 75.0             # a fighter's height in world units (FighterView.HEIGHT)
const REF_MARGIN_X: float = 700.0      # the reference camera's constants
const REF_MARGIN_Y: float = 500.0
const REF_TIER: float = 0.06
const ZOOM_MIN: float = 0.006
const ZOOM_MAX: float = 1.15

# --- divider geometry (section 3) ---
const PHI_MAX: float = 0.5235988       # 30 degrees
const TILT_K: float = 0.6
const TILT_FLOOR: float = 900.0        # units; the tilt uses max(|u|, this)
const TILT_TAU: float = 0.20
const TILT_RATE_MAX: float = 2.0943951 # 120 degrees a second
const TILT_DEAD: float = 0.0523599     # 3 degrees
const ANCHOR_LX: float = 0.28          # x offset of a fighter from the divider centre, times vw, along n.x
const ANCHOR_LY: float = 0.24          # y offset, times vh, along n.y
const ANCHOR_DROP: float = 0.12        # the chest sits this far below the divider centre, times vh
const GAP_FRAC: float = 0.005          # divider gap, fraction of vw (at least GAP_MIN_PX)
const GAP_MIN_PX: float = 3.0
const FEATHER_FRAC: float = 0.05       # dissolve feather at its widest, fraction of vw

# --- pane cameras (section 4) ---
const R_PANE: float = 0.065
const ALT_START: float = 3.0           # body heights above the ground where the altitude zoom-out begins
const ALT_SCALE: float = 40.0
const ALT_FLOOR: float = 0.69
const TAU_X: float = 0.10
const TAU_Y: float = 0.14
const TAU_Z: float = 0.35
const CHEST: float = 38.0              # the point followed, above the feet
const MERGED_TAU: float = 0.2557       # the reference camera's ease: 1 - 0.02^dt
const CAM_Y_MIN: float = -3200.0       # below the deepest sea floor (the reference camera's -180 predates the scaled world)
const CAM_Y_TOP: float = 200.0         # camera y is clamped to CEILING - this
const PLANE_Y: float = 0.7             # the fighter plane on screen in the reference camera, times vh

# --- opening, merging, the slam (sections 6 and 7) ---
const T_OPEN: float = 0.45
const T_CLOSE: float = 0.55
const SLAM_WINDOW: float = 0.8         # a rush this close to its end starts the lean
const SLAM_TIME: float = 0.14
const SLAM_TIME_REDUCED: float = 0.04   # reduced motion: the slam is a near-cut
const SLAM_LEAN: float = 0.0           # how far the panes lean together before the slam (0: they hold until 0.14 s from contact)
const SLAM_TAU: float = 0.03           # stiff pane filters during the slam
const SLAM_FLASH: float = 0.08
const SLAM_CANCEL: float = 0.25

# --- orientation and the swap (section 5) ---
const HYST_M: float = 0.02             # antipode margin, fraction of W
const HYST_M0: float = 225.0           # pass-through dead band (3 body heights)
const FLIP_DWELL: float = 1.0
const T_SWING: float = 0.60
const T_SWING_REDUCED: float = 0.15
const INSTANT_SWAP_E: float = 0.9      # a pane expanded this far hides the swap: flip at once

# --- launch follow (section 8) ---
const LAUNCH_MIN_SPEED: float = 4000.0
const R_LAUNCH: float = 0.06
const LAUNCH_TAU: float = 0.02
const LAUNCH_LEAD: float = 0.05        # s of velocity added to the follow point
const LAUNCH_TRAIL: float = 0.35       # the fighter sits this far from the trailing edge, times vw
const T_ENGAGE: float = 0.32
const LAND_HOLD: float = 0.35
const T_SETTLE: float = 0.60
const T_REVEAL: float = 0.35           # the far pane wipes back in
const MAX_FOLLOW: float = 6.0
const LAND_PUSH: float = 0.08

# --- cinematics (section 9) ---
const R_CINE: float = 0.14             # respected transformation
const CINE_SLIVER: float = 0.14        # the other fighter's share of the screen (Orb decides)
const R_KO: float = 0.16
const KO_DOLLY: float = 1.5
const TIER_PUSH: float = 0.12
const TIER_PUSH_IN: float = 0.25
const TIER_PUSH_HOLD: float = 0.50
const TIER_PUSH_OUT: float = 0.60
const FOLD_FIT: float = 2.4            # the fold's diameter fits this many times across the shorter screen side

# --- comfort limits (section 12); the tests enforce them ---
const ZOOM_RATE: float = 1.2           # e-folds a second, ordinary
const ZOOM_RATE_TRANS: float = 2.4     # in a transition
const ANCHOR_STEP: float = 0.02        # screen motion of a fighter relative to its anchor per tick, times vw
const ANCHOR_STEP_TRANS: float = 0.05
const DIVIDER_STEP: float = 0.06       # divider centre motion per tick, times vw, outside the slam
const SHAKE_CAP: float = 0.03          # times vh
const SHAKE_HIT_STEP: float = 1.0
const MODE_CHANGE_GAP: float = 0.8
