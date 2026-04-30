module QmkNix.Resolve
  ( ResolveError (..)
  , ResolvedConfig (..)
  , ResolvedApp (..)
  , resolve
  , layerSymbol
  , camelToUpperSnake
  ) where

import Control.Monad (when)
import Data.Bits ((.|.), shiftL)
import Data.Char (isUpper, toUpper)
import Data.Function (on)
import Data.List (nubBy, sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as M
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.LayerLayout (appRange, baseLayer, categoryRange, fnLayer)
import QmkNix.Positions.Q0MaxEncoder (Position (Knob))
import QmkNix.Types

data ResolveError
  = TooManyCategories Int
  | TooManyApps Int
  | LedAtKnob Text
  deriving (Show, Eq)

data ResolvedApp = ResolvedApp
  { raIndex           :: Int
  , raApp             :: AppLayer
  , raCategoryIndices :: [Int]
  , raMask            :: Int
  } deriving (Show, Eq)

data ResolvedConfig = ResolvedConfig
  { rcDefault    :: DefaultLayer
  , rcCategories :: [(Int, CategoryLayer)]
  , rcApps       :: [ResolvedApp]
  , rcFnIndex    :: Int
  , rcBaseIndex  :: Int
  } deriving (Show, Eq)

resolve :: DefaultLayer -> [AppLayer] -> Either ResolveError ResolvedConfig
resolve def apps = do
  mapM_ validateLeds apps

  let sortedApps = sortBy (compare `on` appName) apps
      allCats    = nubBy ((==) `on` catName) (concatMap appCategories sortedApps)
      sortedCats = sortBy (compare `on` catName) allCats
      catCount   = length sortedCats
      appCount   = length sortedApps
      catCap     = snd categoryRange - fst categoryRange + 1
      appCap     = snd appRange - fst appRange + 1

  when (catCount > catCap) (Left (TooManyCategories catCount))
  when (appCount > appCap) (Left (TooManyApps appCount))

  let catIndices :: Map Text Int
      catIndices = M.fromList (zip (map catName sortedCats) [fst categoryRange ..])

      resolvedCats = zip [fst categoryRange ..] sortedCats

      resolvedApps = zipWith resolveApp [fst appRange ..] sortedApps
      resolveApp idx app =
        let cixs = mapMaybe (\c -> M.lookup (catName c) catIndices) (appCategories app)
            mask = (1 `shiftL` idx) .|. foldr (.|.) 0 [1 `shiftL` ci | ci <- cixs]
        in ResolvedApp idx app cixs mask

  pure ResolvedConfig
    { rcDefault    = def
    , rcCategories = resolvedCats
    , rcApps       = resolvedApps
    , rcFnIndex    = fnLayer
    , rcBaseIndex  = baseLayer
    }
  where
    validateLeds app
      | Knob `elem` ledPositions (appLeds app) = Left (LedAtKnob (appName app))
      | otherwise                              = Right ()

-- "designTools" -> "DESIGN_TOOLS"; "illustrator" -> "ILLUSTRATOR"
camelToUpperSnake :: Text -> Text
camelToUpperSnake t = T.dropWhile (== '_') (T.concatMap go t)
  where
    go c
      | isUpper c = T.pack ['_', c]
      | otherwise = T.singleton (toUpper c)

layerSymbol :: Text -> Text
layerSymbol n = "LAYER_" <> camelToUpperSnake n
