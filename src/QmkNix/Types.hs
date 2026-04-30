module QmkNix.Types
  ( BundleIdMatch (..)
  , LedColor (..)
  , white, red, green, blue, cyan, magenta, yellow, brown, orange, off
  , LedSet (..)
  , EncoderBinding (..)
  , CategoryLayer (..)
  , AppLayer (..)
  , DefaultLayer (..)
  ) where

import Data.Map.Strict (Map)
import Data.Text (Text)

import QmkNix.Keycodes (Keycode)
import QmkNix.Positions.Q0MaxEncoder (Position)

data BundleIdMatch
  = ExactBundle Text
  | PatternBundle Text
  deriving (Show, Eq)

data LedColor = LedColor
  { ledR :: Int
  , ledG :: Int
  , ledB :: Int
  } deriving (Show, Eq)

white, red, green, blue, cyan, magenta, yellow, brown, orange, off :: LedColor
white   = LedColor 255 255 255
red     = LedColor 255   0   0
green   = LedColor   0 255   0
blue    = LedColor   0   0 255
cyan    = LedColor   0 255 255
magenta = LedColor 255   0 255
yellow  = LedColor 255 255   0
-- RGB-matrix LEDs render "brown" as a warm reddish-tan; tweak if you want
-- it more orange/red on your specific board.
brown   = LedColor 165  42   0
orange  = LedColor 255  90   0
off     = LedColor   0   0   0

data LedSet = LedSet
  { ledPositions :: [Position]
  , ledColor     :: LedColor
  } deriving (Show, Eq)

data EncoderBinding
  = EncoderInherit
  | EncoderBound { encCw :: Keycode, encCcw :: Keycode }
  deriving (Show, Eq)

data CategoryLayer = CategoryLayer
  { catName    :: Text
  , catKeymap  :: Map Position Keycode
  , catEncoder :: EncoderBinding
  } deriving (Show, Eq)

data AppLayer = AppLayer
  { appName       :: Text
  , appBundleId   :: BundleIdMatch
  , appCategories :: [CategoryLayer]
  , appLeds       :: LedSet
  , appKeymap     :: Map Position Keycode
  , appEncoder    :: EncoderBinding
  } deriving (Show, Eq)

data DefaultLayer = DefaultLayer
  { baseKeymap   :: Map Position Keycode
  , baseEncoder  :: EncoderBinding
  , fnKeymap     :: Map Position Keycode
  , fnEncoder    :: EncoderBinding
  } deriving (Show, Eq)
