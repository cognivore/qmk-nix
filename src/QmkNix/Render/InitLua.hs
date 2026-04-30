module QmkNix.Render.InitLua (renderInitLua) where

import Data.Text (Text)
import Data.Text qualified as T

import QmkNix.Render.Common
import QmkNix.Resolve
import QmkNix.Types

renderInitLua :: ResolvedConfig -> Text
renderInitLua rc = T.unlines $
  [ generated "--"
  , ""
  , "-- Substituted at build time by the home-manager module."
  , "local QMK_HID = \"@QMK_HID@\""
  , ""
  , "local exactMatches = {"
  ]
  ++ map renderExact exactApps ++
  [ "}"
  , ""
  , "local patternMatches = {"
  ]
  ++ map renderPattern patternApps ++
  [ "}"
  , ""
  ]
  ++ staticBody
  where
    exactApps   = [ ra | ra <- rcApps rc, isExact   (appBundleId (raApp ra)) ]
    patternApps = [ ra | ra <- rcApps rc, isPattern (appBundleId (raApp ra)) ]
    isExact   (ExactBundle _)   = True; isExact   _ = False
    isPattern (PatternBundle _) = True; isPattern _ = False

    renderExact ra = case appBundleId (raApp ra) of
      ExactBundle bid -> "    [\"" <> bid <> "\"] = " <> int (raMask ra) <> ","
      _               -> ""
    renderPattern ra = case appBundleId (raApp ra) of
      PatternBundle pat -> "    [\"" <> pat <> "\"] = " <> int (raMask ra) <> ","
      _                 -> ""

staticBody :: [Text]
staticBody =
  [ "local function maskForBundle(bid)"
  , "  if bid == nil then return 0 end"
  , "  local m = exactMatches[bid]"
  , "  if m then return m end"
  , "  for pat, mm in pairs(patternMatches) do"
  , "    if string.match(bid, pat) then return mm end"
  , "  end"
  , "  return 0"
  , "end"
  , ""
  , "local lastMask = nil"
  , ""
  , "local function setLayerMask(mask)"
  , "  if mask == lastMask then return end"
  , "  lastMask = mask"
  , "  hs.task.new(QMK_HID, function(exit, _, stderr)"
  , "    if exit ~= 0 then"
  , "      hs.logger.new(\"qmkNix\"):e(\"q0-max-hid failed: \" .. (stderr or \"\"))"
  , "      lastMask = nil"
  , "    end"
  , "  end, { tostring(mask) }):start()"
  , "end"
  , ""
  , "local function onAppActivated(_, eventType, app)"
  , "  if eventType ~= hs.application.watcher.activated then return end"
  , "  local bid = app and app:bundleID() or nil"
  , "  setLayerMask(maskForBundle(bid))"
  , "end"
  , ""
  , "-- Held in a global so the Lua GC doesn't collect the watcher (Hammerspoon #681)."
  , "qmkNixWatcher = hs.application.watcher.new(onAppActivated)"
  , "qmkNixWatcher:start()"
  , ""
  , "qmkNixConfigWatcher = hs.pathwatcher.new(hs.configdir, hs.reload):start()"
  , ""
  , "-- Watchdog: re-assert the current app's layer every 30s in case of transient disconnect."
  , "hs.timer.doEvery(30, function()"
  , "  local app = hs.application.frontmostApplication()"
  , "  local bid = app and app:bundleID() or nil"
  , "  local mask = maskForBundle(bid)"
  , "  lastMask = nil"
  , "  setLayerMask(mask)"
  , "end)"
  ]
