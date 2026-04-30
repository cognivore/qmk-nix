-- Adobe Illustrator (CC 2024+; bundle id com.adobe.illustrator, stable across
-- versions per Adobe community guidance).
--
-- Viewport navigation lives on the numpad cardinal keys, since arrow keys in
-- Illustrator nudge the selection, not the viewport:
--
--   P8 = Page Up           — scroll viewport up
--   P2 = Page Down         — scroll viewport down
--   P4 = Cmd+Page Up       — scroll viewport left
--   P6 = Cmd+Page Down     — scroll viewport right
--
-- Encoder = Cmd+= / Cmd+-, inherited from the designTools category. Enable
-- Preferences → Performance → Animated Zoom (requires GPU Performance) so the
-- encoder zooms toward the cursor instead of centring on the canvas.
module QmkNix.Plugins.Apps.Illustrator (illustrator) where

import Data.Map.Strict qualified as M

import QmkNix.Keycodes
import QmkNix.Plugins.Categories.DesignTools (designTools)
import QmkNix.Positions.Q0MaxEncoder
import QmkNix.Types

illustrator :: AppLayer
illustrator = AppLayer
  { appName       = "illustrator"
  , appBundleId   = ExactBundle "com.adobe.illustrator"
  , appCategories = [designTools]
  , appLeds       = LedSet [P2, P4, P6, P8] brown
  , appKeymap     = M.fromList
      [ (P8, kc "PGUP")
      , (P2, kc "PGDN")
      , (P4, lgui (kc "PGUP"))
      , (P6, lgui (kc "PGDN"))
      ]
  , appEncoder    = EncoderInherit
  }
