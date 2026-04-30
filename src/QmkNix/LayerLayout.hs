module QmkNix.LayerLayout
  ( baseLayer
  , fnLayer
  , categoryRange
  , appRange
  , maxLayer
  ) where

baseLayer :: Int
baseLayer = 0

categoryRange :: (Int, Int)
categoryRange = (1, 7)

appRange :: (Int, Int)
appRange = (8, 30)

fnLayer :: Int
fnLayer = 31

maxLayer :: Int
maxLayer = 32
