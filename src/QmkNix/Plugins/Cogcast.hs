-- Cogcast: turn the 18 user-available positions on the Q0 Max into slot
-- keys that report to a host daemon (clawed-cogworker / `cogworkd`) over
-- RAW HID, and accept per-key colour paints from that daemon.
--
-- Disabled by default: when `ccEnabled = False`, codegen output is
-- byte-identical to a non-cogcast build. That keeps the existing golden
-- tests valid.
--
-- The reserved positions (M1..M5, PMns, PPls, PEnt, Knob) are not
-- available as slots — they retain their stock keymap entries.
module QmkNix.Plugins.Cogcast
  ( CogcastConfig (..)
  , defaultCogcast
  , allCogcast
  , slotKeycodeFor
  , isUsableSlotPosition
  ) where

import Data.Text qualified as T

import QmkNix.Keycodes (Keycode (KcLit))
import QmkNix.Positions.Q0MaxEncoder
  ( Position (..), ledIndex )

data CogcastConfig = CogcastConfig
  { ccEnabled  :: Bool
  -- ^ When False, no slot keycodes are emitted and no extra C is added
  -- to rules.mk. Codegen output is identical to a non-cogcast build.
  , ccSlotKeys :: [Position]
  -- ^ Positions on the BASE layer to convert into slot keys. Must be a
  -- subset of `usableSlotPositions`; anything else is ignored.
  } deriving stock (Show, Eq)

defaultCogcast :: CogcastConfig
defaultCogcast = CogcastConfig
  { ccEnabled  = False
  , ccSlotKeys = []
  }

-- | Turn on Cogcast for every user-available position. This is the
-- recommended profile for a numpad fully repurposed as a trigger pad.
allCogcast :: CogcastConfig
allCogcast = CogcastConfig
  { ccEnabled  = True
  , ccSlotKeys = usableSlotPositions
  }

usableSlotPositions :: [Position]
usableSlotPositions =
  [ Esc, Del, Tab, Bspc
  , NumLk, PSls, PAst
  , P7, P8, P9
  , P4, P5, P6
  , P1, P2, P3
  , P0, PDot
  ]

isUsableSlotPosition :: Position -> Bool
isUsableSlotPosition p = p `elem` usableSlotPositions

-- | Slot keycode for a position, addressed by the position's LED index.
-- Returns Nothing for positions without an LED (Knob).
slotKeycodeFor :: Position -> Maybe Keycode
slotKeycodeFor pos = do
  n <- ledIndex pos
  pure (KcLit ("QMK_NIX_SLOT_KEY_" <> T.pack (show n)))
