module QmkNix.Render.RulesMk (renderRulesMk) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.Plugins.Cogcast (CogcastConfig (ccEnabled))
import QmkNix.Render.Common
import QmkNix.Resolve (ResolvedConfig (rcCogcast))

renderRulesMk :: ResolvedConfig -> Text
renderRulesMk rc = T.unlines $
  [ generated "#"
  , ""
  , "SRC += qmk_nix_raw_hid.c"
  , "SRC += qmk_nix_indicators.c"
  , "SRC += qmk_nix_wireless_fallback.c"
  ]
  ++ ([ "SRC += qmk_nix_slots.c" | ccEnabled (rcCogcast rc) ])
