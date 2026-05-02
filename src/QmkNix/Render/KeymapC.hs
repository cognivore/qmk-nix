module QmkNix.Render.KeymapC (renderKeymapC) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as M
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.Keycodes
import QmkNix.Plugins.Cogcast (CogcastConfig (..), slotKeycodeFor)
import QmkNix.Positions.Q0MaxEncoder (Position, layoutRows, ledIndex)
import QmkNix.Render.Common
import QmkNix.Resolve
import QmkNix.Types

-- The shape of a layer that the keymap renderer cares about.
data Layer = Layer
  { lyrSym :: Text
  , lyrKm  :: Map Position Keycode
  , lyrEnc :: EncoderBinding
  }

renderKeymapC :: ResolvedConfig -> Text
renderKeymapC rc = T.unlines $
  [ generated "//"
  , "#include QMK_KEYBOARD_H"
  , "#include \"keychron_common.h\""
  , "#include \"qmk_nix_layers.h\""
  , ""
  , "// clang-format off"
  , "const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {"
  ]
  ++ concatMap renderKeymapEntry layers
  ++
  [ "};"
  , "// clang-format on"
  , ""
  , "#if defined(ENCODER_MAP_ENABLE)"
  , "const uint16_t PROGMEM encoder_map[][NUM_ENCODERS][2] = {"
  ]
  ++ map renderEncoderEntry layers ++
  [ "};"
  , "#endif"
  , ""
  ]
  ++ renderIndicatorTables rc
  ++ renderAppMasks rc
  where
    layers :: [Layer]
    layers =
         [ Layer "LAYER_BASE" (applyCogcast (rcCogcast rc) (baseKeymap (rcDefault rc))) (baseEncoder (rcDefault rc)) ]
      ++ [ Layer (layerSymbol (catName c)) (catKeymap c) (catEncoder c)
         | (_, c) <- rcCategories rc ]
      ++ [ Layer (layerSymbol (appName (raApp ra))) (appKeymap (raApp ra)) (appEncoder (raApp ra))
         | ra <- rcApps rc ]
      ++ [ Layer "LAYER_FN" (fnKeymap (rcDefault rc)) (fnEncoder (rcDefault rc)) ]

    -- Substitute the BASE keycode for slot positions with QMK_NIX_SLOT_KEY_<led>.
    -- Identity when cogcast is disabled.
    applyCogcast :: CogcastConfig -> Map Position Keycode -> Map Position Keycode
    applyCogcast cc km
      | ccEnabled cc = M.mapWithKey replace km
      | otherwise    = km
      where
        slotSet = ccSlotKeys cc
        replace pos orig
          | pos `elem` slotSet = fromMaybe orig (slotKeycodeFor pos)
          | otherwise          = orig

renderKeymapEntry :: Layer -> [Text]
renderKeymapEntry (Layer sym km _) =
  [ "    [" <> sym <> "] = LAYOUT_tenkey_27("
  ]
  ++ rowLines ++
  [ "    ),"
  ]
  where
    n = length layoutRows
    rowLines = zipWith renderLine [0 :: Int ..] layoutRows
    renderLine idx row =
      let body = T.intercalate ", " (map (renderKeycode . keyAt) row)
          comma = if idx == n - 1 then "" else ","
      in "        " <> body <> comma
    keyAt p = M.findWithDefault trns p km

renderEncoderEntry :: Layer -> Text
renderEncoderEntry (Layer sym _ enc) = case enc of
  EncoderBound cw ccw ->
    "    [" <> sym <> "] = { ENCODER_CCW_CW(" <> renderKeycode ccw <> ", " <> renderKeycode cw <> ") },"
  EncoderInherit ->
    "    [" <> sym <> "] = { ENCODER_CCW_CW(KC_TRNS, KC_TRNS) },"

renderIndicatorTables :: ResolvedConfig -> [Text]
renderIndicatorTables rc =
  [ "// LED indicator data — only app layers contribute."
  , "typedef struct { uint8_t led; uint8_t r; uint8_t g; uint8_t b; } qmk_nix_led_t;"
  , "typedef struct { const qmk_nix_led_t *leds; uint8_t count; } qmk_nix_led_set_t;"
  , ""
  ]
  ++ concatMap renderAppLeds (rcApps rc)
  ++
  [ "const qmk_nix_led_set_t qmk_nix_indicators_per_layer[QMK_NIX_LAYER_COUNT] = {"
  ]
  ++ map renderDispatch (rcApps rc) ++
  [ "};"
  ]
  where
    arrName ra = "qmk_nix_leds_" <> sanitize (appName (raApp ra))
    sanitize = T.toLower . T.map (\c -> if c == ' ' || c == '-' then '_' else c)

    renderAppLeds ra =
      let app   = raApp ra
          lc    = ledColor (appLeds app)
          leds  = mapMaybe ledIndex (ledPositions (appLeds app))
      in
        [ "static const qmk_nix_led_t " <> arrName ra <> "[] = {"
        ]
        ++ map (renderLed lc) leds ++
        [ "};"
        , ""
        ]

    renderLed (LedColor r g b) idx =
      "    { " <> int idx <> ", " <> int r <> ", " <> int g <> ", " <> int b <> " },"

    renderDispatch ra =
      let app   = raApp ra
          n     = length (mapMaybe ledIndex (ledPositions (appLeds app)))
      in "    [" <> layerSymbol (appName app) <> "] = { " <> arrName ra <> ", " <> int n <> " },"

-- App masks (one per registered app, alphabetical order — matches Resolve).
-- Wireless-fallback cycle keybind iterates this array.
renderAppMasks :: ResolvedConfig -> [Text]
renderAppMasks rc =
  [ ""
  , "// Layer-state masks per app, indexed 0..QMK_NIX_APP_COUNT-1."
  , "const layer_state_t qmk_nix_app_masks[] = {"
  ]
  ++ entries ++
  [ "};"
  ]
  where
    entries
      | null (rcApps rc) = ["    0u, // (no app plugins selected — sentinel; never read since QMK_NIX_APP_COUNT == 0)"]
      | otherwise        = map renderMask (rcApps rc)
    renderMask ra =
      "    (layer_state_t)" <> int (raMask ra) <> "u, // " <> appNameOf ra
    appNameOf ra =
      let appLayer = raApp ra
      in appName appLayer
