import XMonad
import XMonad.Config.Gnome
import XMonad.Util.EZConfig
import XMonad.Actions.CycleWS       (nextWS, prevWS, shiftToNext, shiftToPrev, moveTo, toggleWS, nextScreen, shiftNextScreen, shiftTo, WSType(..), Direction1D(..))
import qualified XMonad.StackSet    as W
import XMonad.Hooks.FadeInactive

myLogHook :: X ()
myLogHook = fadeInactiveLogHook fadeAmount
    where fadeAmount = 0.4

main = xmonad $ gnomeConfig {
    modMask = mod4Mask,
    borderWidth = 2,
    normalBorderColor = "#888888",
    focusedBorderColor = "#FF0000",
    logHook = myLogHook >> logHook gnomeConfig
    }
    `additionalKeysP`
    [  ("M-e",         spawn "gnome-terminal")
     , ("M-<D>",        windows W.focusDown)
     , ("M-<R>",        windows W.focusDown)
     , ("M-<U>",        windows W.focusUp)
     , ("M-<L>",        windows W.focusUp)
     , ("M1-C-<U>",        moveTo Next EmptyWS)
     , ("M1-C-<D>",        moveTo Prev EmptyWS)
     , ("M1-C-<L>",        moveTo Prev HiddenNonEmptyWS)
     , ("M1-C-<R>",        moveTo Next HiddenNonEmptyWS)
     , ("M1-C-S-<R>",      shiftToNext >> nextWS)
     , ("M1-C-S-<L>",      shiftToPrev >> prevWS)
     , ("M1-<Tab>",     toggleWS)
     , ("M-<Return>",   windows W.swapMaster)
    ]

