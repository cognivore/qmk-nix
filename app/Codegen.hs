module Main (main) where

import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Options.Applicative
import System.Directory (createDirectoryIfMissing)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

import QmkNix.Plugins.Default (defaultLayer)
import QmkNix.Plugins.Registry (availableApps, lookupApp)
import QmkNix.Render.InitLua (renderInitLua)
import QmkNix.Render.KeymapC (renderKeymapC)
import QmkNix.Render.LayersH (renderLayersH)
import QmkNix.Render.RulesMk (renderRulesMk)
import QmkNix.Resolve (resolve)
import QmkNix.Types (AppLayer)

data Cmd
  = ListPlugins
  | Generate GenOpts

data GenOpts = GenOpts
  { genPlugins :: [Text]
  , genOutDir  :: FilePath
  }

cmdParser :: Parser Cmd
cmdParser = subparser
  ( command "list-plugins" (info (pure ListPlugins) (progDesc "List available app plugins"))
 <> command "gen"          (info (Generate <$> genOptsParser) (progDesc "Generate firmware sources + Hammerspoon init.lua"))
  )

genOptsParser :: Parser GenOpts
genOptsParser = GenOpts
  <$> many (T.pack <$> strOption
        (  long "plugin"
        <> short 'p'
        <> metavar "NAME"
        <> help "App plugin to include (repeatable). Use 'list-plugins' to discover names."))
  <*> strOption
        (  long "out"
        <> short 'o'
        <> metavar "DIR"
        <> help "Output directory; will be created if missing.")

main :: IO ()
main = do
  cmd <- execParser
    (info (cmdParser <**> helper)
      (fullDesc <> progDesc "qmk-nix codegen — Q0 Max firmware + macOS daemon"))
  case cmd of
    ListPlugins -> mapM_ TIO.putStrLn availableApps
    Generate g  -> doGenerate g

doGenerate :: GenOpts -> IO ()
doGenerate g = do
  apps <- mapM resolveOne (genPlugins g)
  case resolve defaultLayer apps of
    Left err -> do
      hPutStrLn stderr ("resolve error: " ++ show err)
      exitFailure
    Right rc -> do
      createDirectoryIfMissing True (genOutDir g)
      TIO.writeFile (genOutDir g </> "keymap.c")         (renderKeymapC rc)
      TIO.writeFile (genOutDir g </> "qmk_nix_layers.h") (renderLayersH rc)
      TIO.writeFile (genOutDir g </> "rules.mk")         (renderRulesMk rc)
      TIO.writeFile (genOutDir g </> "init.lua")         (renderInitLua rc)

resolveOne :: Text -> IO AppLayer
resolveOne name = case lookupApp name of
  Just a  -> pure a
  Nothing -> do
    hPutStrLn stderr ("unknown plugin: " ++ T.unpack name)
    exitFailure
