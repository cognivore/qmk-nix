module QmkNix.Render.LayersH (renderLayersH) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.LayerLayout (appRange, categoryRange, maxLayer)
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
  , "};"
  ]
  where
    renderCat (idx, c) = define (layerSymbol (catName c)) idx
    renderApp ra       = define (layerSymbol (appName (raApp ra))) (raIndex ra)

    define :: Text -> Int -> Text
    define name n = "#define " <> padR 30 name <> int n
