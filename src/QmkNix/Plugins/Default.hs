-- Hardcoded Q0 Max default keymap. BASE + FN are lifted verbatim from
-- Keychron/qmk_firmware @ 2025q3 SHA 9d72c98b3fd1f48ea2b6dc1de8485f0c83aac7e2 :
--   keyboards/keychron/q0_max/encoder/keymaps/keychron/keymap.c
--
-- BASE = layer 0, lives in default_layer_state (always on).
-- FN   = layer 31; M5 holds MO(FN) so the bottom-left key activates it
--        momentarily, exactly as on stock.
module QmkNix.Plugins.Default (defaultLayer) where

import Data.Map.Strict qualified as M

import QmkNix.Keycodes
import QmkNix.Positions.Q0MaxEncoder
import QmkNix.Types

defaultLayer :: DefaultLayer
defaultLayer = DefaultLayer
  { baseKeymap = M.fromList
      [ (Knob, kc "MUTE"), (Esc,  kc "ESC"),  (Del,  kc "DEL"),  (Tab,  kc "TAB"),  (Bspc, kc "BSPC")
      , (M1,   mc 1),      (NumLk,kc "NUM"),  (PSls, kc "PSLS"), (PAst, kc "PAST"), (PMns, kc "PMNS")
      , (M2,   mc 2),      (P7,   kc "P7"),   (P8,   kc "P8"),   (P9,   kc "P9"),   (PPls, kc "PPLS")
      , (M3,   mc 3),      (P4,   kc "P4"),   (P5,   kc "P5"),   (P6,   kc "P6")
      , (M4,   mc 4),      (P1,   kc "P1"),   (P2,   kc "P2"),   (P3,   kc "P3"),   (PEnt, kc "PENT")
      , (M5,   moFn),      (P0,   kc "P0"),                                          (PDot, kc "PDOT")
      ]
  , baseEncoder = EncoderBound { encCw = kc "VOLU", encCcw = kc "VOLD" }

  , fnKeymap = M.fromList
      [ (Knob, ug "TOGG"), (Esc,  bt 1),      (Del,  bt 2),      (Tab,  bt 3),      (Bspc, p2p4g)
      -- M1 on FN replaces upstream's `_______` with our manual layer-cycle key.
      -- (Without Fn held it still produces the stock MC_1 macro from BASE.)
      , (M1,   kcRaw "QMK_NIX_CYCLE_APP")
      ,                    (NumLk,ug "NEXT"), (PSls, ug "VALU"), (PAst, ug "HUEU"), (PMns, trns)
      , (M2,   trns),      (P7,   ug "PREV"), (P8,   ug "VALD"), (P9,   ug "HUED"), (PPls, trns)
      , (M3,   trns),      (P4,   ug "SATU"), (P5,   ug "SPDU"), (P6,   kc "MPRV")
      -- Fn+PEnt jumps to STM32 DFU bootloader, so re-flashing doesn't need
      -- the unplug-hold-Esc dance after the first flash.
      , (M4,   trns),      (P1,   ug "SATD"), (P2,   ug "SPDD"), (P3,   kc "MPLY"), (PEnt, kcRaw "QK_BOOT")
      , (M5,   trns),      (P0,   ug "TOGG"),                                       (PDot, kc "MNXT")
      ]
  , fnEncoder = EncoderBound { encCw = ug "VALU", encCcw = ug "VALD" }
  }
