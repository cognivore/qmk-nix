module QmkNix.Render.LayersH (renderLayersH) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.LayerLayout (appRange, categoryRange, maxLayer)
import QmkNix.Plugins.Cogcast (CogcastConfig (ccEnabled))
import QmkNix.Render.Common
import QmkNix.Resolve
import QmkNix.Types (CategoryLayer (catName), AppLayer (appName))

renderLayersH :: ResolvedConfig -> Text
renderLayersH rc = T.unlines $
  [ generated "//"
  , "#pragma once"
  , "#include \"quantum.h\""
  , ""
  , define "LAYER_BASE" (rcBaseIndex rc)
  ]
  ++ map renderCat (rcCategories rc)
  ++ map renderApp (rcApps rc) ++
  [ define "LAYER_FN" (rcFnIndex rc)
  , ""
  , define "QMK_NIX_LAYER_COUNT" maxLayer
  , define "QMK_NIX_CAT_FIRST"   (fst categoryRange)
  , define "QMK_NIX_CAT_LAST"    (snd categoryRange)
  , define "QMK_NIX_APP_FIRST"   (fst appRange)
  , define "QMK_NIX_APP_LAST"    (snd appRange)
  , define "QMK_NIX_APP_COUNT"   (length (rcApps rc))
  , ""
  , "// Custom keycodes used by firmware-stub/qmk_nix_wireless_fallback.c."
  , "enum qmk_nix_custom_keycodes {"
  , "    QMK_NIX_CYCLE_APP = SAFE_RANGE,"
  ]
  ++ cogcastEnumLines
  ++
  [ "};"
  ]
  ++ cogcastDefines
  where
    renderCat (idx, c) = define (layerSymbol (catName c)) idx
    renderApp ra       = define (layerSymbol (appName (raApp ra))) (raIndex ra)

    define :: Text -> Int -> Text
    define name n = "#define " <> padR 30 name <> int n

    -- Slot keycodes — one per LED index 0..25. Emitted only when Cogcast is
    -- enabled, so non-cogcast builds are byte-identical to today.
    cogcastEnumLines
      | ccEnabled (rcCogcast rc) =
          [ "    QMK_NIX_SLOT_KEY_" <> int n <> "," | n <- [0 .. 25 :: Int] ]
      | otherwise = []

    cogcastDefines
      | ccEnabled (rcCogcast rc) =
          [ ""
          , "#define QMK_NIX_SLOT_KEY_FIRST QMK_NIX_SLOT_KEY_0"
          , "#define QMK_NIX_SLOT_KEY_LAST  QMK_NIX_SLOT_KEY_25"
          , "#define QMK_NIX_COGCAST_ENABLED 1"
          ]
      | otherwise = []
