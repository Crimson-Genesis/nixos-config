import Colors.TomorrowNight
import Control.Monad (when)
import Data.Char (toUpper)
import qualified Data.Map as M
import Data.Maybe (isJust)
import Graphics.X11.ExtraTypes.XF86
import System.IO (hClose, hPutStr)
import XMonad
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.CycleWS (WSType (WSIs), nextScreen, prevScreen)
import XMonad.Actions.MouseResize
import XMonad.Actions.RotSlaves (rotAllDown, rotSlavesDown)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.WithAll (killAll)
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.InsertPosition
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers (doCenterFloat, doFullFloat, doRectFloat, isFullscreen)
import XMonad.Hooks.WindowSwallowing
import XMonad.Layout.BinarySpacePartition
import XMonad.Layout.LayoutModifier
import XMonad.Layout.MultiToggle (EOT (EOT), mkToggle, single, (??))
import qualified XMonad.Layout.MultiToggle as MT (Toggle (..))
import XMonad.Layout.MultiToggle.Instances (StdTransformers (MIRROR, NBFULL, NOBORDERS))
import XMonad.Layout.NoBorders
import XMonad.Layout.Renamed
import XMonad.Layout.Simplest
import XMonad.Layout.Tabbed
import XMonad.Layout.WindowArranger (WindowArrangerMsg (..), windowArrange)
import XMonad.Layout.WindowNavigation
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig (mkNamedKeymap)
import XMonad.Util.Hacks (windowedFullscreenFixEventHook)
import XMonad.Util.NamedActions
import XMonad.Util.NamedScratchpad
import XMonad.Util.Run (spawnPipe)
import XMonad.Util.SpawnOnce

myFont :: String
myFont =
  "xft:JetBrainsMono Nerd Font Mono:regular:size=9:antialias=true:hinting=true,Noto Color Emoji:size=9"

myModMask :: KeyMask
myModMask = mod4Mask

myTerminal :: String
myTerminal = "alacritty"

myBrowser :: String
myBrowser = "zen"

myFileManager :: String
myFileManager = "doublecmd"

myEditor :: String
myEditor = myTerminal ++ " -e nvim "

myBorderWidth :: Dimension
myBorderWidth = 0

mySoundPlayer :: String
mySoundPlayer = "ffplay -nodisp -autoexit "

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

myScratchPads :: [NamedScratchpad]
myScratchPads =
  [ NS "terminal" spawnTerm findTerm manageTerm,
    NS "mocp" spawnMocp findMocp manageMocp,
    NS "calculator" spawnCalc findCalc manageCalc
  ]
  where
    spawnTerm = myTerminal ++ " -t scratchpad"
    findTerm = title =? "scratchpad"
    manageTerm = customFloating $ W.RationalRect l t w h
      where
        h = 0.9
        w = 0.9
        t = 0.95 - h
        l = 0.95 - w
    spawnMocp = myTerminal ++ " -t mocp -e mocp"
    findMocp = title =? "mocp"
    manageMocp = customFloating $ W.RationalRect l t w h
      where
        h = 0.9
        w = 0.9
        t = 0.95 - h
        l = 0.95 - w
    spawnCalc = "qalculate-gtk"
    findCalc = className =? "Qalculate-gtk"
    manageCalc = customFloating $ W.RationalRect l t w h
      where
        h = 0.5
        w = 0.4
        t = 0.75 - h
        l = 0.70 - w

-- Defining a bunch of layouts, many that I don't use.
bsp =
  renamed [Replace "bsp"] $
    windowNavigation $
      smartBorders $
        emptyBSP

myTabTheme =
  def
    { fontName = myFont,
      activeColor = color15,
      inactiveColor = color08,
      activeBorderColor = color15,
      inactiveBorderColor = colorBack,
      activeTextColor = colorBack,
      inactiveTextColor = color16
    }

tabs =
  renamed [Replace "tabs"] $
    tabbed shrinkText myTabTheme

-- The layout hook
myLayoutHook =
  avoidStruts $
    mouseResize $
      windowArrange $
        mkToggle (NBFULL ?? NOBORDERS ?? EOT) $
          myDefaultLayout
  where
    myDefaultLayout =
      bsp
        ||| noBorders tabs

-- myWorkspaces = [" 0 "," 1 ", " 2 ", " 3 ", " 4 ", " 5 ", " 6 ", " 7 ", " 8 ", " 9 "]
myWorkspaces = [" dev ", " www ", " sys ", " vid ", " pen ", " studio ", " qbit ", " mail ", " vm ", " mus "]

myWorkspaceIndices = M.fromList $ zipWith (,) myWorkspaces [1 ..] -- (,) == \x y -> (x,y)

doShiftAndView :: WorkspaceId -> ManageHook
doShiftAndView ws = doF (W.greedyView ws) <+> doShift ws

myFloatRules =
  [ className =? "confirm" --> doCenterFloat,
    className =? "file_progress" --> doCenterFloat,
    className =? "dialog" --> doCenterFloat,
    className =? "download" --> doCenterFloat,
    className =? "error" --> doCenterFloat,
    className =? "Gimp" --> doCenterFloat,
    className =? "notification" --> doCenterFloat,
    className =? "pinentry-gtk-2" --> doCenterFloat,
    className =? "splash" --> doCenterFloat,
    className =? "toolbar" --> doCenterFloat,
    className =? "Xdg-desktop-portal-gtk" --> doCenterFloat,
    className =? "Yad" --> doCenterFloat,
    className =? "flameshot" --> doCenterFloat,
    className =? "manpage" --> doRectFloat (W.RationalRect 0.1 0.1 0.8 0.8),
    className =? "btop_" --> doRectFloat (W.RationalRect 0.40 0.00 0.60 1.00),
    className =? "_nvtop" --> doRectFloat (W.RationalRect 0.00 0.00 0.40 1.00),
    className =? "btop" --> doRectFloat (W.RationalRect 0.02 0.02 0.96 0.96),
    className =? "htop" --> doRectFloat (W.RationalRect 0.02 0.02 0.96 0.96),
    className =? "nvtop" --> doRectFloat (W.RationalRect 0.10 0.10 0.80 0.80),
    className =? "Gcolor3" --> doCenterFloat,
    className =? "copyq" --> doRectFloat (W.RationalRect 0.1 0.1 0.8 0.8),
    className =? "toipe" --> doCenterFloat,
    className =? "nmtui" --> doCenterFloat,
    className =? "pavucontrol" --> doCenterFloat,
    className =? ".blueman-manager-wrapped" --> doCenterFloat,
    title =? "Oracle VM VirtualBox Manager" --> doCenterFloat,
    title =? "Order Chain - Market Snapshots" --> doCenterFloat,
    (className =? "zen" <&&> resource =? "Dialog") --> doCenterFloat
  ]

myWorkspaceRules =
  [ className =? "Alacritty" --> doShiftAndView " dev ",
    className =? "zen" --> doShiftAndView " www ",
    className =? "doublecmd" --> doShiftAndView " sys ",
    className =? "mpv" --> doShiftAndView " vid ",
    className =? "rnote" --> doShiftAndView " pen ",
    className =? "Inkscape" --> doShiftAndView " pen ",
    className =? "qBittorrent" --> doShiftAndView " qbit ",
    className =? "VirtualBox Manager" --> doShiftAndView " vm ",
    className =? "thunderbird" --> doShiftAndView " mail ",
    className =? "libreoffice-startcenter" --> doShiftAndView " mus ",
    className =? "libreoffice-calc" --> doShiftAndView " mus ",
    className =? "libreoffice-draw" --> doShiftAndView " mus ",
    className =? "libreoffice-math" --> doShiftAndView " mus ",
    className =? "libreoffice-writer" --> doShiftAndView " mus ",
    className =? "libreoffice-impress" --> doShiftAndView " mus ",
    className =? "Soffice" --> doShiftAndView " mus ",
    className =? "resolve" --> doShiftAndView " studio ",
    className =? "obs" --> doShiftAndView " studio "
  ]

myFullscreenRules =
  [isFullscreen --> doFullFloat]

myManageHook :: ManageHook
myManageHook =
  insertPosition End Newer
    <+> composeAll myFloatRules
    <+> composeAll myWorkspaceRules
    <+> composeAll myFullscreenRules
    <+> namedScratchpadManageHook myScratchPads

subtitle' :: String -> ((KeyMask, KeySym), NamedAction)
subtitle' x =
  ( (0, 0),
    NamedAction $
      map toUpper $
        sep ++ "\n-- " ++ x ++ " --\n" ++ sep
  )
  where
    sep = replicate (6 + length x) '-'

showKeybindings :: [((KeyMask, KeySym), NamedAction)] -> NamedAction
showKeybindings x = addName "Show Keybindings" $ io $ do
  h <- spawnPipe $ "yad --text-info --fontname=\"JetBrainsMono Nerd Font Mono 12\" --fore=#46d9ff back=#282c36 --center --geometry=1200x800 --title \"XMonad keybindings\""
  hPutStr h (unlines $ showKmSimple x)
  hClose h
  return ()

myKeys :: XConfig l0 -> [((KeyMask, KeySym), NamedAction)]
myKeys c =
  -- (subtitle "Custom Keys":) $ mkNamedKeymap c $
  let subKeys str ks = subtitle' str : mkNamedKeymap c ks
   in subKeys
        "Xmonad Essentials"
        [ ("M-S-r", addName "Recompile and Restart Xmonad" $ spawn "xmonad --recompile && xmonad --restart"),
          ("M-q", addName "Kill focused window" $ kill1),
          ("M-S-q", addName "Kill all windows on WS" $ killAll),
          ("M1-<Space>", addName "Launch rofi" $ spawn "rofi -show drun"),
          ("M-C-S-l", addName "LockScreen" $ spawn "betterlockscreen -l"),
          ("M-\\", addName "Launch toipe" $ spawn "toipe-toggle easy"),
          ("M-S-\\", addName "Launch toipe" $ spawn "toipe-toggle medium"),
          ("M1-S-\\", addName "Launch toipe" $ spawn "toipe-toggle hard"),
          ("M-S-b", addName "Toggle bar show/hide" $ sendMessage ToggleStruts),
          ("M-/", addName "DTOS Help" $ spawn "~/.local/bin/dtos-help"),
          ("M-c", addName "Clipboard History" $ spawn "copyq show"),
          ("M-S-c", addName "Clear Clipboard" $ spawn "sh -c 'printf \"No\nYes\" | rofi -dmenu -p \"Clear Clipboard?\" | grep -qx Yes && copyq eval \"for(var i=count()-1;i>=0;--i) remove(i)\"'")
        ]
        ^++^ subKeys
          "Rofi Launchers"
          [ ("M1-' r", addName "Launch rofi - run" $ spawn "rofi -show run"),
            ("M1-' w", addName "Launch rofi - window" $ spawn "rofi -show window"),
            ("M1-' e", addName "Launch rofi - emoji" $ spawn "rofimoji -a copy"),
            ("M1-' c", addName "Launch rofi - calc" $ spawn "rofi -show calc"),
            ("M1-' s", addName "Launch rofi - search" $ spawn "rofi-search"),
            ("M1-' S-s", addName "Launch rofi - search" $ spawn "rofi-search --clear-history"),
            ("M1-' i", addName "Launch rofi - icons" $ spawn "rofi -show nerdy"),
            ("M1-' m", addName "Launch rofi - manpages" $ spawn "rofi -show man")
          ]
        ^++^ subKeys
          "Rofi Tmux"
          [ ("M1-; s", addName "Launch rofi-tmux session" $ spawn "rofi-tmux session"),
            ("M1-; a", addName "Launch rofi-tmux create-all" $ spawn "rofi-tmux create-all"),
            ("M1-; w", addName "Launch rofi-tmux window" $ spawn "rofi-tmux window"),
            ("M1-; k", addName "Launch rofi-tmux kill" $ spawn "rofi-tmux kill"),
            ("M1-; S-k", addName "Launch rofi-tmux kill-all" $ spawn "rofi-tmux kill-all"),
            ("M1-; d", addName "Launch rofi-tmux delete" $ spawn "rofi-tmux delete"),
            ("M1-; c", addName "Launch rofi-tmux cleanup" $ spawn "rofi-tmux cleanup"),
            ("M1-; b", addName "Launch rofi-tmux backup" $ spawn "rofi-tmux backup"),
            ("M1-; e", addName "Launch rofi-tmux rename" $ spawn "rofi-tmux edit")
          ]
        ^++^ subKeys
          "Function-Keys"
          [ ("M-<F1>", addName "Pavucontrol Toggle" $ spawn "pgrep -af pavucontrol >/dev/null && pkill pavucontrol || pavucontrol"),
            ("M-<F2>", addName "Launch nmtui" $ spawn ("pgrep -x nmtui >/dev/null && pkill nmtui || " ++ myTerminal ++ " --class nmtui -e nmtui")),
            -- ("M-<F3>", addName "" $ spawn ()),
            ("M-<F4>", addName "Screenkey Toggle" $ spawn "screenkey-toggle"),
            -- ("M-<F5>", addName "" $ spawn ()),
            -- ("M-<F5>", addName "" $ spawn ()),
            -- ("M-<F6>", addName "" $ spawn ()),
            -- ("M-<F7>", addName "" $ spawn ()),
            -- ("M-<F8>", addName "" $ spawn ()),
            -- ("M-<F9>", addName "" $ spawn ()),
            ("M-<F10>", addName "Color Picker - xcolor" $ spawn "xcolor -c 'rgb(%{r},%{g},%{b}) #%{02Hr}%{02Hg}%{02Hb}' -S 10 -s clipboard"),
            ("M-S-<F10>", addName "Color Picker - gpick" $ spawn "pgrep -af gcolor3 >/dev/null && pkill gcolor3 || gcolor3"),
            ("M-<F11>", addName "Email client" $ runOrRaise "thunderbird" (resource =? "thunderbird")),
            ("M-S-<F11>", addName "Email client" $ runOrRaise "thunderbird" (resource =? "thunderbird"))
            -- ("M-<F12>", addName "" $ spawn )
          ]
        ^++^ subKeys
          "Switch to workspace"
          [ ("M-i", addName "Switch to workspace 0" $ (windows $ W.greedyView $ myWorkspaces !! 0)),
            ("M-o", addName "Switch to workspace 1" $ (windows $ W.greedyView $ myWorkspaces !! 1)),
            ("M-p", addName "Switch to workspace 2" $ (windows $ W.greedyView $ myWorkspaces !! 2)),
            ("M-n", addName "Switch to workspace 3" $ (windows $ W.greedyView $ myWorkspaces !! 3)),
            ("M-m", addName "Switch to workspace 4" $ (windows $ W.greedyView $ myWorkspaces !! 4)),
            ("M-S-i", addName "Switch to workspace 5" $ (windows $ W.greedyView $ myWorkspaces !! 5)),
            ("M-S-o", addName "Switch to workspace 6" $ (windows $ W.greedyView $ myWorkspaces !! 6)),
            ("M-S-p", addName "Switch to workspace 7" $ (windows $ W.greedyView $ myWorkspaces !! 7)),
            ("M-S-n", addName "Switch to workspace 8" $ (windows $ W.greedyView $ myWorkspaces !! 8)),
            ("M-S-m", addName "Switch to workspace 9" $ (windows $ W.greedyView $ myWorkspaces !! 9))
          ]
        ^++^ subKeys
          "Send window to workspace"
          [ ("M-S-1", addName "Send to workspace 1" $ (windows $ W.shift $ myWorkspaces !! 0)),
            ("M-S-2", addName "Send to workspace 2" $ (windows $ W.shift $ myWorkspaces !! 1)),
            ("M-S-3", addName "Send to workspace 3" $ (windows $ W.shift $ myWorkspaces !! 2)),
            ("M-S-4", addName "Send to workspace 4" $ (windows $ W.shift $ myWorkspaces !! 3)),
            ("M-S-5", addName "Send to workspace 5" $ (windows $ W.shift $ myWorkspaces !! 4)),
            ("M-S-6", addName "Send to workspace 6" $ (windows $ W.shift $ myWorkspaces !! 5)),
            ("M-S-7", addName "Send to workspace 7" $ (windows $ W.shift $ myWorkspaces !! 6)),
            ("M-S-8", addName "Send to workspace 8" $ (windows $ W.shift $ myWorkspaces !! 7)),
            ("M-S-9", addName "Send to workspace 9" $ (windows $ W.shift $ myWorkspaces !! 8)),
            ("M-S-0", addName "Send to workspace 8" $ (windows $ W.shift $ myWorkspaces !! 9))
          ]
        ^++^ subKeys
          "Window navigation"
          [ ("M-h", addName "Focus left" $ sendMessage $ Go L),
            ("M-j", addName "Focus down" $ sendMessage $ Go D),
            ("M-k", addName "Focus up" $ sendMessage $ Go U),
            ("M-l", addName "Focus right" $ sendMessage $ Go R),
            ("M-r", addName "Rotate BSP" $ sendMessage Rotate),
            ("M-S-h", addName "Swap left" $ sendMessage $ XMonad.Layout.WindowNavigation.Swap L),
            ("M-S-j", addName "Swap down" $ sendMessage $ XMonad.Layout.WindowNavigation.Swap D),
            ("M-S-k", addName "Swap up" $ sendMessage $ XMonad.Layout.WindowNavigation.Swap U),
            ("M-S-l", addName "Swap right" $ sendMessage $ XMonad.Layout.WindowNavigation.Swap R),
            ("M-S-,", addName "Rotate all windows except master" $ rotSlavesDown),
            ("M-S-.", addName "Rotate all windows current stack" $ rotAllDown),
            ( "M-<Space>",
              addName "Toggle Floating" $
                withFocused $ \w -> do
                  floats <- gets (W.floating . windowset)
                  if M.member w floats
                    then windows (W.sink w)
                    else windows (W.float w (W.RationalRect 0.1 0.1 0.8 0.8))
            )
          ]
        -- \^++^ subKeys
        --   "Dmenu scripts"
        --   [ ("M-p h", addName "List all dmscripts" $ spawn "dm-hub"),
        --     ("M-p a", addName "Choose ambient sound" $ spawn "dm-sounds"),
        --     ("M-p b", addName "Set background" $ spawn "dm-setbg"),
        --     ("M-p c", addName "Choose color scheme" $ spawn "~/.local/bin/dtos-colorscheme"),
        --     ("M-p C", addName "Pick color from scheme" $ spawn "dm-colpick"),
        --     ("M-p e", addName "Edit config files" $ spawn "dm-confedit"),
        --     ("M-p i", addName "Take a screenshot" $ spawn "dm-maim"),
        --     ("M-p k", addName "Kill processes" $ spawn "dm-kill"),
        --     ("M-p m", addName "View manpages" $ spawn "dm-man"),
        --     ("M-p n", addName "Store and copy notes" $ spawn "dm-note"),
        --     ("M-p o", addName "Browser bookmarks" $ spawn "dm-bookman"),
        --     ("M-p p", addName "Passmenu" $ spawn "passmenu -p \"Pass: \""),
        --     ("M-p q", addName "Logout Menu" $ spawn "dm-logout"),
        --     ("M-p r", addName "Listen to online radio" $ spawn "dm-radio"),
        --     ("M-p s", addName "Search various engines" $ spawn "dm-websearch"),
        --     ("M-p t", addName "Translate text" $ spawn "dm-translate")
        --   ]
        ^++^ subKeys
          "Favorite programs"
          [ ("M1-C-l", addName "Launch terminal" $ spawn (myTerminal)),
            ("M1-C-k", addName "Launch web browser" $ spawn (myBrowser)),
            ("M1-C-j", addName "Launch doublecmd" $ spawn (myFileManager)),
            ("M-[", addName "Launch btop - term" $ spawn (myTerminal ++ " -e btop")),
            ("M-S-[", addName "Launch htop - term" $ spawn (myTerminal ++ " -e htop")),
            ("M-]", addName "Launch nvtop - term" $ spawn (myTerminal ++ " -e nvtop")),
            ("M1-[", addName "Launch btop - float" $ spawn ("pgrep -x btop >/dev/null && pkill btop || " ++ myTerminal ++ " --class btop -e btop")),
            ("M1-S-[", addName "Launch htop - float" $ spawn ("pgrep -x htop >/dev/null && pkill htop || " ++ myTerminal ++ " --class htop -e htop")),
            ("M1-]", addName "Launch nvtop - float" $ spawn ("pgrep -x nvtop >/dev/null && pkill nvtop || " ++ myTerminal ++ " --class nvtop -e nvtop")),
            ("M1-S-]", addName "Toggle btop+nvtop" $ spawn "toggle_btop_nvtop")
          ]
        ^++^ subKeys
          "Monitors"
          [ ("M-.", addName "Switch focus to next monitor" $ nextScreen),
            ("M-,", addName "Switch focus to prev monitor" $ prevScreen)
          ]
        -- Switch layouts
        ^++^ subKeys
          "Switch layouts"
          [ ("M-<Tab>", addName "Switch to next layout" $ sendMessage NextLayout),
            ("M-f", addName "Toggle noborders/full" $ sendMessage (MT.Toggle NBFULL))
          ]
        -- Window resizing
        ^++^ subKeys
          "Window resizing"
          [ ("M-M1-h", addName "Expand left" $ sendMessage (ExpandTowards L)),
            ("M-M1-j", addName "Expand down" $ sendMessage (ExpandTowards D)),
            ("M-M1-k", addName "Expand up" $ sendMessage (ExpandTowards U)),
            ("M-M1-l", addName "Expand right" $ sendMessage (ExpandTowards R))
          ]
        -- Scratchpads
        -- Toggle show/hide these programs. They run on a hidden workspace.
        -- When you toggle them to show, it brings them to current workspace.
        -- Toggle them to hide and it sends them back to hidden workspace (NSP).
        ^++^ subKeys
          "Scratchpads"
          [ ("M-s i", addName "Toggle scratchpad terminal" $ namedScratchpadAction myScratchPads "terminal"),
            -- ("M-s m", addName "Toggle scratchpad mocp" $ namedScratchpadAction myScratchPads "mocp"),
            ("M-s e", addName "Toggle scratchpad calculator" $ namedScratchpadAction myScratchPads "calculator")
          ]
        -- Controls for mocp music player (SUPER-u followed by a key)
        -- \^++^ subKeys
        --   "Mocp music player"
        --   [ ("M-u p", addName "mocp play" $ spawn "mocp --play"),
        --     ("M-u l", addName "mocp next" $ spawn "mocp --next"),
        --     ("M-u h", addName "mocp prev" $ spawn "mocp --previous"),
        --     ("M-u <Space>", addName "mocp toggle pause" $ spawn "mocp --toggle-pause")
        --   ]
        -- Multimedia Keys
        ^++^ subKeys
          "Multimedia keys"
          [ ("<XF86AudioPlay>", addName "Play/Pause" $ spawn "playerctl play-pause"),
            ("<XF86AudioPrev>", addName "Previous Track" $ spawn "playerctl previous"),
            ("<XF86AudioNext>", addName "Next Track" $ spawn "playerctl next"),
            ("<XF86AudioMute>", addName "Toggle audio mute" $ spawn "vol_brigh_control mute"),
            ("<XF86AudioLowerVolume>", addName "Lower vol" $ spawn "vol_brigh_control voldown 10"),
            ("<XF86AudioRaiseVolume>", addName "Raise vol" $ spawn "vol_brigh_control volup 10"),
            ("<XF86MonBrightnessUp>", addName "Increse the brightness by 5%" $ spawn "vol_brigh_control brightup 10"),
            ("<XF86MonBrightnessDown>", addName "Decrese the brightness by 5%" $ spawn "vol_brigh_control brightdown 10"),
            ("M-b v", addName "Set vol%" $ spawn "vol_brigh_control vol --rofi"),
            ("M-b b", addName "Set brightness%" $ spawn "vol_brigh_control bright --rofi"),
            ("<XF86HomePage>", addName "Open home page" $ spawn (myBrowser ++ " https://www.youtube.com/@Crimson-Genesis")),
            ("<XF86Search>", addName "Web search (dmscripts)" $ spawn "dm-websearch"),
            ("<XF86Calculator>", addName "Calculator" $ runOrRaise "qalculate-gtk" (resource =? "qalculate-gtk")),
            ("<Print>", addName "Take screenshot (flameshot)" $ spawn "flameshot gui"),
            ("S-<Print>", addName "Take screenshot (flameshot)" $ spawn "flameshot full")
          ]
  where
    -- The following lines are needed for named scratchpads.
    nonNSP = WSIs (return (\ws -> W.tag ws /= "NSP"))
    nonEmptyNonNSP = WSIs (return (\ws -> isJust (W.stack ws) && W.tag ws /= "NSP"))

myMouseBindings :: XConfig Layout -> M.Map (KeyMask, Button) (Window -> X ())
myMouseBindings conf =
  M.fromList
    [ ( (modMask conf, button1),
        \w -> do
          floats <- gets (W.floating . windowset)
          when (M.member w floats) $
            focus w >> mouseMoveWindow w
      ),
      ( (modMask conf, button3),
        \w -> do
          floats <- gets (W.floating . windowset)
          when (M.member w floats) $
            focus w >> mouseResizeWindow w
      )
    ]

myStartupHook :: X ()
myStartupHook = do
  spawnOnce "xsetroot -cursor_name left_ptr"
  spawnOnce "copyq"
  spawnOnce "picom"
  spawnOnce "xset r rate 125 120"
  spawnOnce "feh --bg-fill $HOME/.config/xmonad/wallpaper.jpg"
  spawnOnce "dunst"
  spawnOnce myTerminal

main =
  xmonad $
    addDescrKeys' ((mod4Mask, xK_F12), showKeybindings) myKeys $
      ewmh $
        docks $
          def
            { keys = \_ -> M.empty,
              manageHook = myManageHook <+> manageDocks,
              handleEventHook =
                windowedFullscreenFixEventHook
                  <> swallowEventHook
                    ( className
                        =? "Alacritty"
                        <||> className
                        =? "st-256color"
                        <||> className
                        =? "XTerm"
                    )
                    (return True),
              modMask = myModMask,
              terminal = myTerminal,
              layoutHook = myLayoutHook,
              workspaces = myWorkspaces,
              startupHook = myStartupHook,
              borderWidth = myBorderWidth,
              mouseBindings = myMouseBindings
            }
