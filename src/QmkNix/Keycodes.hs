module QmkNix.Keycodes
  ( Keycode (..)
  , renderKeycode
  , trns
  , noKey
  , kc
  , kcRaw
  , mo
  , moFn
  , lt
  , mc
  , bt
  , p2p4g
  , ug
  , lgui, lctl, lalt, lsft
  , rgui, rctl, ralt, rsft
  ) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.LayerLayout (fnLayer)

data Keycode
  = KcLit Text
  | KcMo Int
  | KcLt Int Keycode
  | KcMod Text Keycode
  deriving (Show, Eq)

renderKeycode :: Keycode -> Text
renderKeycode = \case
  KcLit s   -> s
  KcMo n    -> "MO(" <> T.pack (show n) <> ")"
  KcLt n k  -> "LT(" <> T.pack (show n) <> "," <> renderKeycode k <> ")"
  KcMod m k -> m <> "(" <> renderKeycode k <> ")"

trns, noKey :: Keycode
trns  = KcLit "KC_TRNS"
noKey = KcLit "KC_NO"

kc :: Text -> Keycode
kc s = KcLit ("KC_" <> s)

kcRaw :: Text -> Keycode
kcRaw = KcLit

mo :: Int -> Keycode
mo = KcMo

moFn :: Keycode
moFn = KcMo fnLayer

lt :: Int -> Keycode -> Keycode
lt = KcLt

mc :: Int -> Keycode
mc n = KcLit ("MC_" <> T.pack (show n))

bt :: Int -> Keycode
bt n = KcLit ("BT_HST" <> T.pack (show n))

p2p4g :: Keycode
p2p4g = KcLit "P2P4G"

ug :: Text -> Keycode
ug s = KcLit ("UG_" <> s)

lgui, lctl, lalt, lsft :: Keycode -> Keycode
lgui = KcMod "LGUI"
lctl = KcMod "LCTL"
lalt = KcMod "LALT"
lsft = KcMod "LSFT"

rgui, rctl, ralt, rsft :: Keycode -> Keycode
rgui = KcMod "RGUI"
rctl = KcMod "RCTL"
ralt = KcMod "RALT"
rsft = KcMod "RSFT"
