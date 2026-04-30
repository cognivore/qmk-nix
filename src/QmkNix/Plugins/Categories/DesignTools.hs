module QmkNix.Plugins.Categories.DesignTools (designTools) where

import Data.Map.Strict qualified as M

import QmkNix.Keycodes
import QmkNix.Types

-- Cmd+= / Cmd+- on the encoder is canonical zoom across most macOS design apps.
-- Apps in this category that don't override get this for free.
designTools :: CategoryLayer
designTools = CategoryLayer
  { catName    = "designTools"
  , catKeymap  = M.empty
  , catEncoder = EncoderBound
      { encCw  = lgui (kc "EQL")
      , encCcw = lgui (kc "MINS")
      }
  }
