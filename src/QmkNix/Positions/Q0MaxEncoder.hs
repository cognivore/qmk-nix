-- Symbolic positions on a Keychron Q0 Max (encoder variant).
-- Source: github.com/Keychron/qmk_firmware @ 2025q3 SHA 9d72c98b3fd1f48ea2b6dc1de8485f0c83aac7e2
--   keyboards/keychron/q0_max/encoder/{keyboard.json,encoder.c}
module QmkNix.Positions.Q0MaxEncoder
  ( Position (..)
  , layoutRows
  , layoutOrder
  , matrixCoord
  , ledIndex
  ) where

-- Physical key positions, in the order they appear in LAYOUT_tenkey_27(...).
-- Position naming: numpad keys are PN, the encoder is Knob, the left macro
-- column is M1..M5 (M5 is the stock momentary-FN slot), the top-row keys
-- right of the encoder are Esc/Del/Tab/Bspc.
--
-- Note: PPls is 2u tall (covers row 2 col 4 + row 3 col 4); PEnt is 2u tall
-- (covers row 4 col 4 + row 5 col 4); P0 is 2u wide (covers row 5 col 1 +
-- row 5 col 2). Those "covered" matrix cells are NO_KEY in the layout and
-- have no LED in g_led_config.
data Position
  = Knob   | Esc    | Del    | Tab    | Bspc
  | M1     | NumLk  | PSls   | PAst   | PMns
  | M2     | P7     | P8     | P9     | PPls
  | M3     | P4     | P5     | P6
  | M4     | P1     | P2     | P3     | PEnt
  | M5     | P0     | PDot
  deriving stock (Show, Eq, Ord, Enum, Bounded)

layoutRows :: [[Position]]
layoutRows =
  [ [Knob, Esc, Del, Tab, Bspc]
  , [M1,   NumLk, PSls, PAst, PMns]
  , [M2,   P7, P8, P9, PPls]
  , [M3,   P4, P5, P6]
  , [M4,   P1, P2, P3, PEnt]
  , [M5,   P0,        PDot]
  ]

layoutOrder :: [Position]
layoutOrder = concat layoutRows

matrixCoord :: Position -> (Int, Int)
matrixCoord = \case
  Knob -> (0,0); Esc   -> (0,1); Del  -> (0,2); Tab  -> (0,3); Bspc -> (0,4)
  M1   -> (1,0); NumLk -> (1,1); PSls -> (1,2); PAst -> (1,3); PMns -> (1,4)
  M2   -> (2,0); P7    -> (2,1); P8   -> (2,2); P9   -> (2,3); PPls -> (2,4)
  M3   -> (3,0); P4    -> (3,1); P5   -> (3,2); P6   -> (3,3)
  M4   -> (4,0); P1    -> (4,1); P2   -> (4,2); P3   -> (4,3); PEnt -> (4,4)
  M5   -> (5,0); P0    -> (5,1); PDot -> (5,3)

-- LED index in g_led_config (encoder.c). The encoder press has no LED, so
-- ledIndex Knob = Nothing.
ledIndex :: Position -> Maybe Int
ledIndex = \case
  Knob  -> Nothing
  Esc   -> Just 0;  Del   -> Just 1;  Tab   -> Just 2;  Bspc -> Just 3
  M1    -> Just 4;  NumLk -> Just 5;  PSls  -> Just 6;  PAst -> Just 7;  PMns -> Just 8
  M2    -> Just 9;  P7    -> Just 10; P8    -> Just 11; P9   -> Just 12; PPls -> Just 13
  M3    -> Just 14; P4    -> Just 15; P5    -> Just 16; P6   -> Just 17
  M4    -> Just 18; P1    -> Just 19; P2    -> Just 20; P3   -> Just 21; PEnt -> Just 22
  M5    -> Just 23; P0    -> Just 24; PDot  -> Just 25
