-- Dispatch table: plugin name → AppLayer. To register a new app, add an
-- entry here and the corresponding QmkNix.Plugins.Apps.<Name> module.
module QmkNix.Plugins.Registry
  ( availableApps
  , lookupApp
  ) where

import Data.Text (Text)

import QmkNix.Plugins.Apps.Illustrator qualified as Illustrator
import QmkNix.Types

availableApps :: [Text]
availableApps = ["illustrator"]

lookupApp :: Text -> Maybe AppLayer
lookupApp = \case
  "illustrator" -> Just Illustrator.illustrator
  _             -> Nothing
