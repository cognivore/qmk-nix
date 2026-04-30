module QmkNix.Render.RulesMk (renderRulesMk) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.Render.Common
import QmkNix.Resolve (ResolvedConfig)

renderRulesMk :: ResolvedConfig -> Text
renderRulesMk _ = T.unlines
  [ generated "#"
  , ""
  , "SRC += qmk_nix_raw_hid.c"
  , "SRC += qmk_nix_indicators.c"
  , "SRC += qmk_nix_wireless_fallback.c"
  ]
