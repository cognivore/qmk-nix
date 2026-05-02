module Main (main) where

import Data.ByteString.Lazy (ByteString)
import Data.Text qualified as T
import Data.Text.Lazy qualified as TL
import Data.Text.Lazy.Encoding qualified as TL
import Test.Tasty
import Test.Tasty.Golden (goldenVsString)

import QmkNix.Plugins.Apps.Illustrator qualified as Illustrator
import QmkNix.Plugins.Cogcast (allCogcast, defaultCogcast)
import QmkNix.Plugins.Default (defaultLayer)
import QmkNix.Render.InitLua (renderInitLua)
import QmkNix.Render.KeymapC (renderKeymapC)
import QmkNix.Render.LayersH (renderLayersH)
import QmkNix.Render.RulesMk (renderRulesMk)
import QmkNix.Resolve (resolveWith)

main :: IO ()
main = defaultMain $
  testGroup "qmk-nix"
    [ testGroup "illustrator-only" $
        let rc = case resolveWith defaultLayer [Illustrator.illustrator] defaultCogcast of
              Right r  -> r
              Left err -> error ("resolve: " <> show err)
            golden name f =
              goldenVsString name
                ("tests/golden/illustrator/" <> name)
                (pure (toBL (f rc)))
        in
          [ golden "keymap.c"         renderKeymapC
          , golden "qmk_nix_layers.h" renderLayersH
          , golden "rules.mk"         renderRulesMk
          , golden "init.lua"         renderInitLua
          ]
    , testGroup "cogcast-illustrator" $
        let rc = case resolveWith defaultLayer [Illustrator.illustrator] allCogcast of
              Right r  -> r
              Left err -> error ("resolve: " <> show err)
            golden name f =
              goldenVsString name
                ("tests/golden/cogcast-illustrator/" <> name)
                (pure (toBL (f rc)))
        in
          [ golden "keymap.c"         renderKeymapC
          , golden "qmk_nix_layers.h" renderLayersH
          , golden "rules.mk"         renderRulesMk
          , golden "init.lua"         renderInitLua
          ]
    ]
  where
    toBL :: T.Text -> ByteString
    toBL = TL.encodeUtf8 . TL.fromStrict
