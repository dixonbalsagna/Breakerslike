class_name CamParams
## Every number of the dynamic split screen (docs/camera/split-screen.md), in one place. Screen fractions are of the
## screen height (vh) or width (vw) as named; times are seconds on the fixed 60 Hz step; distances are world units.
## Defaults marked "Orb decides" in the design doc are the ones a playtest will change.

# --- the trigger (section 2) ---
const R_SPLIT: float = 0.035           # split when a fighter's height falls under this fraction of vh (Orb decides)
const R_MERGE: float = 0.047           # merge when it stays above this (Orb decides)
const R_BEAM_MIN: float = 0.032        # a beam struggle keeps the merged wide shot down to this
const MIN_PX: float = 18.0             # under 600 px of screen height the split line is at least this many pixels
const R_FLOOR: float = 0.032          # camera v2: no fighter is shown smaller than this anywhere (23 px at 720p)
const R_MAX: float = 0.14              # camera v2: the largest the one view zooms in (101 px at 720p), times the zoom setting
const R_CLOSE: float = 0.20            # a close-up shot (transformation, KO) may go this close, times the zoom setting
const FIT_MARGIN_X: float = 450.0      # camera v2: the one view's margin round two fighters, so melee is 11% of the height
const ZOOM_PREF_DEFAULT: float = 7.0   # the zoom setting, 0 to 10
const ZOOM_PREF_K: float = 0.08        # every size target is multiplied by exp(K (pref - 7))
const SHAKE_PREF_DEFAULT: float = 2.0  # the shake setting, 0 to 10; effective scale = pref / 10 * SHAKE_PREF_TOP
const SHAKE_PREF_TOP: float = 1.4      # 10 of 10 is the old prototype's strength (cap 4.2% of the height)
const SPLIT_DWELL: float = 0.25
const WIDE_HOLD: float = 1.0          # extra dwell while the fighters are still moving apart: the shared zoom-out ("flying around the world") lasts this much longer
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
const ZONE_W: float = 0.0  # 0 = off. Was 0.51 (UI's clear-zone width) to keep fighters out from under UI's edge chips; Orb preferred the longer shared zoom-out, and the chips dodge the fighters instead             # UI's fighter-clear zone is 51% of the width (docs/ui/hud-spec.md 2.1): both fighters fit inside it
const ZOOM_MIN: float = 0.006
const ZOOM_MAX: float = 1.15          # the reference camera's cap, kept for the parity docs; v2 uses R_MAX

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
const R_PANE: float = 0.085
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
const R_LAUNCH: float = 0.08
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

# --- the lag bound (camera v2 section 2) ---
const LAG_SOFT: float = 0.06           # a tracked fighter this far from his anchor (screen widths): ordinary filter
const LAG_HARD: float = 0.20           # ... this far: the focus is held to it (a whip)
const LAG_GAIN: float = 6.0            # the filters speed up by 1 + LAG_GAIN * (e - SOFT) / (HARD - SOFT)
const LAG_CUT: float = 1.5             # farther than this in one tick: a cut (a counted safety net)
const CUT_FADE: float = 0.08           # the cut's fade-in from 70% brightness, seconds
const CUT_DIM: float = 0.30
const REDUCED_CUT_FADE: float = 0.30

# --- fighters in depth (docs/camera/depth-and-chains.md) ---
const K_FACTOR: float = 1.8660254      # 1 / (2 tan 15 degrees): the camera's distance to the fighter plane is K_FACTOR * vh / zoom
const TAN_HALF_FOV: float = 0.2679491924   # tan(15 degrees): the lens is 30 degrees
const DEPTH_S_MIN: float = 0.2         # perspective scale floor, so the anchor compensation cannot blow up
const LEAD_FRAC: float = 0.35          # how far toward the aimed building the focus leads
const LEAD_MAX_X: float = 0.18         # ... at most this fraction of the width, on screen
const LEAD_MAX_Y: float = 0.12         # ... and of the height
const HIT_PUSH: float = 0.06           # zoom push on the first building hit; later links push less
const HIT_PUSH_LATER: float = 0.03
const HIT_UP: float = 0.15
const HIT_HOLD_FIRST: float = 0.35     # the sim's hold on a first hit (buildings-in-depth.md 4b)
const HIT_HOLD_LATER: float = 0.12
const HIT_DOWN: float = 0.40

# --- the hybrid launch rule and the cut (camera-v2.md sections 3 and 12) ---
const HOLD_MAX: float = 1.5            # the camera stays on the attacker at most this long before the impact cut
const CUT_SHOT: float = 0.5            # the impact cut lasts this long
const CUT_PUSH: float = 0.10           # ... zoomed in this much past the chase size
const CUTAWAY_MIN_PX: float = 70.0     # the occlusion hole's radius is at least this, and 1.6 x the fighter's height
const CUTAWAY_K: float = 1.6
const SHAKE_FALLOFF: float = 4000.0   # a shake event at this distance from a pane's centre is scaled down to SHAKE_FAR (Controls' shake pass)
const SHAKE_FAR: float = 0.35         # ... and the pane farther from the event gets this share of it
const SHAKE_DECAY: float = 0.02       # per second, the fx consumer's decay
const MODE_CHANGE_GAP: float = 0.8
